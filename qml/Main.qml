import QtQuick 2.9
import Ubuntu.Components 1.3
import "components"
import "js/Storage.js" as Storage
import "js/SynologyApi.js" as SynoApi
import "js/Theme.js" as Theme
import "js/DownloadManager.js" as DownloadMgr
import QtMultimedia 5.8

MainView {
    id: mainView
    objectName: "mainView"
    applicationName: "music-for-nas-synology.puqsoftware"
    width: units.gu(45)
    height: units.gu(80)
    backgroundColor: isLoggedIn ? Theme.background : Theme.primary
    headerColor: isLoggedIn ? Theme.background : Theme.primary
    anchorToKeyboard: true
    focus: true

    // Bluetooth headset / hardware media keys (delivered when the app has focus).
    // Play/pause is additionally intercepted system-wide by the shell, which is
    // why it also works on the lock screen; next/previous reach only the focused app.
    Keys.onPressed: {
        switch (event.key) {
        case Qt.Key_MediaNext:
            event.accepted = true;
            nextTrack();
            break;
        case Qt.Key_MediaPrevious:
            event.accepted = true;
            prevTrack();
            break;
        case Qt.Key_MediaPlay:
        case Qt.Key_MediaPause:
        case Qt.Key_MediaTogglePlayPause:
            event.accepted = true;
            togglePlayPause();
            break;
        case Qt.Key_MediaStop:
            event.accepted = true;
            if (globalPlayer && globalPlayer.playbackState === Audio.PlayingState) globalPlayer.pause();
            break;
        }
    }

    // Session State
    property string serverUrl: ""
    property string sid: ""
    property string synotoken: ""
    property string username: ""
    property bool isLoggedIn: false
    property bool isOfflineMode: false
    property bool loading: false
    property string appVersion: "1.0.0"

    // Global Audio Player
    // The player playlist holds the FULL playback queue (all real track URLs),
    // so that the system sound indicator can drive next/previous
    // directly through media-hub, and tracks auto-advance when one finishes.
    // The player is wrapped in a Loader so that it can be recreated if the
    // media-hub session dies (e.g. the service restarted).
    property bool _ignorePlaylistChange: false
    property int _playerRecreations: 0

    Loader {
        id: playerLoader
        sourceComponent: playerComponent
    }

    QtObject {
        id: playerHolder
        property var player: null
        property var playlist: null
    }

    property alias globalPlayer: playerHolder.player
    property alias playerPlaylist: playerHolder.playlist

    Component {
        id: playerComponent
        Audio {
            audioRole: Audio.MusicRole

            playlist: Playlist {
                onCurrentIndexChanged: {
                    if (mainView._ignorePlaylistChange) return;
                    mainView.onPlaylistIndexChanged(mainView.playerPlaylist ? mainView.playerPlaylist.currentIndex : -1);
                }
            }

            Component.onCompleted: {
                playerHolder.player = this;
                playerHolder.playlist = this.playlist;
            }
        }
    }
    
    // Player State Properties
    property var currentTrack: {"title": "", "artist": ""}

    property int currentTrackIndex: -1
    
    property alias currentPlaylistModel: _currentPlaylistModel
    ListModel {
        id: _currentPlaylistModel
    }
    
    property alias downloadQueueModel: _downloadQueueModel
    ListModel {
        id: _downloadQueueModel
    }
    
    property int repeatMode: 0 // 0: no repeat, 1: repeat all, 2: repeat one
    property bool shuffleMode: false
    property real downloadProgress: -1 // -1 = not downloading, 0..1 = progress
    property int trackGeneration: 0 // incremented on each new track to force UI reset
    
    signal downloadFinished()
    signal cacheCleared()
    
    property int _playbackFailCount: 0

    function buildTrackUrl(track) {
        if (!track || !track.id) return "";
        if (DownloadMgr.isDownloaded(track.id)) {
            return "file://" + DownloadMgr.getDownloadPath(track.id);
        }
        return SynoApi.getStreamUrl(mainView.serverUrl, mainView.sid, mainView.synotoken, track.id);
    }

    function rebuildPlayerPlaylist(startIndex) {
        // Stop any pending retries from the previous track: their ticks must
        // never interfere with the rebuild of the new one.
        playRetryTimer.stop();
        mainView._ignorePlaylistChange = true;
        playerPlaylist.clear();

        var urls = [];
        for (var i = 0; i < _currentPlaylistModel.count; i++) {
            urls.push(buildTrackUrl(_currentPlaylistModel.get(i)));
        }

        if (urls.length > 0) {
            playerPlaylist.addItems(urls);
            if (startIndex >= 0 && startIndex < playerPlaylist.itemCount) {
                playerPlaylist.currentIndex = startIndex;
            }
        }

        mainView._ignorePlaylistChange = false;
    }

    function playTrack(list, index) {
        if (!list) return;
        var len = list.count !== undefined ? list.count : list.length;
        if (len === 0 || index < 0 || index >= len) return;
        
        if (list !== _currentPlaylistModel) {
            _currentPlaylistModel.clear();
            for (var i = 0; i < len; i++) {
                _currentPlaylistModel.append(list.count !== undefined ? list.get(i) : list[i]);
            }
        }

        currentTrackIndex = index;
        currentTrack = _currentPlaylistModel.get(index);
        if (!currentTrack || !currentTrack.id) return;
        savePlaylist();

        var cached = DownloadMgr.isDownloaded(currentTrack.id);
        if (cached) {
            mainView.downloadProgress = -1;
        } else {
            mainView.downloadProgress = 0;
            autoDownload(currentTrack);
        }
        
        mainView.trackGeneration++;
        rebuildPlayerPlaylist(index);
        startPlayback();
    }

    // media-hub drops play() commands while a (network) stream is still
    // prerolling: isAudioSource() is false then, and playback silently
    // never starts. Worse, Qt marks the player as Playing even when the
    // command was dropped, so a plain play() retry is a no-op. The retry
    // logic therefore resets that state (pause+play) and only trusts that
    // playback really started once the position is advancing.
    Timer {
        id: playRetryTimer
        interval: 1000
        repeat: true
        property int attempts: 0
        property int advancingTicks: 0
        property int lastPosition: -1
        onTriggered: {
            attempts++;
            if (attempts > 15) {
                stop();
                // Playback never started: the media-hub session may be dead
                // (service restarted / session gone). Recreate the player
                // once or twice and try again.
                if (mainView._playerRecreations < 2) {
                    mainView.recreatePlayer();
                }
                return;
            }

            var pos = globalPlayer.position;
            if (globalPlayer.hasAudio && pos > lastPosition) {
                advancingTicks++;
                if (advancingTicks >= 2) {
                    stop();
                    lastPosition = -1;
                    mainView._playerRecreations = 0;
                    return;
                }
            } else {
                advancingTicks = 0;
                // Reset the optimistic Playing state (set even when media-hub
                // dropped the play command) so play() is sent again.
                if (globalPlayer.playbackState === Audio.PlayingState) {
                    globalPlayer.pause();
                }
                globalPlayer.play();
            }
            lastPosition = pos;
        }
    }

    function startPlayback() {
        playRetryTimer.stop();
        playRetryTimer.attempts = 0;
        playRetryTimer.advancingTicks = 0;
        playRetryTimer.lastPosition = -1;
        globalPlayer.play();
        playRetryTimer.start();
    }

    // The media-hub session can die while the app lives (e.g. the media-hub
    // service crashed/restarted): every call then fails with "No such object
    // path". Recreate the QtMultimedia player so a fresh session is used.
    function recreatePlayer() {
        playRetryTimer.stop();
        mainView._ignorePlaylistChange = true;
        playerHolder.player = null;
        playerHolder.playlist = null;
        playerLoader.active = false;
        playerLoader.active = true;
        mainView._ignorePlaylistChange = false;
        _playerRecreations++;
        applyPlaybackMode();
        if (currentTrackIndex >= 0 && _currentPlaylistModel.count > 0) {
            rebuildPlayerPlaylist(currentTrackIndex);
            startPlayback();
        }
    }

    // After the offline cache is cleared (files deleted), the queue may still
    // point to deleted file:// URLs. Rebuild it so tracks stream (and
    // re-download) again, restarting the current track if it was playing.
    function onDownloadsChanged() {
        mainView.cacheCleared();
        if (_currentPlaylistModel.count > 0 && currentTrackIndex >= 0) {
            var wasPlaying = globalPlayer && globalPlayer.playbackState === Audio.PlayingState;
            rebuildPlayerPlaylist(currentTrackIndex);
            if (wasPlaying) startPlayback();
        }
    }

    // Called when media-hub changes the current track by itself
    // (indicator next/previous or natural end-of-track auto-advance).
    function onPlaylistIndexChanged(idx) {
        if (idx < 0 || idx >= _currentPlaylistModel.count) return;
        if (idx === currentTrackIndex) return;

        currentTrackIndex = idx;
        var trk = _currentPlaylistModel.get(idx);
        if (!trk || !trk.id) return;

        currentTrack = trk;
        mainView.trackGeneration++;
        savePlaylist();

        var cached = DownloadMgr.isDownloaded(trk.id);
        if (cached) {
            mainView.downloadProgress = -1;
        } else {
            mainView.downloadProgress = 0;
            autoDownload(trk);
        }
    }

    function applyPlaybackMode() {
        if (!playerPlaylist) return;
        if (repeatMode === 2) {
            playerPlaylist.playbackMode = Playlist.CurrentItemInLoop;
        } else if (repeatMode === 1) {
            playerPlaylist.playbackMode = Playlist.Loop;
        } else {
            playerPlaylist.playbackMode = Playlist.Sequential;
        }
    }

    onRepeatModeChanged: applyPlaybackMode()

    function clearPlayerQueue() {
        playRetryTimer.stop();
        mainView._ignorePlaylistChange = true;
        playerPlaylist.clear();
        mainView._ignorePlaylistChange = false;
        globalPlayer.stop();
        _currentPlaylistModel.clear();
        currentTrackIndex = -1;
        currentTrack = {"title": "", "artist": ""};
        mainView.downloadProgress = -1;
        savePlaylist();
    }

    // Rebuilds the media-hub track list to match the queue model while
    // preserving the current playing state.
    function resyncPlayerPlaylist() {
        var wasPlaying = globalPlayer && globalPlayer.playbackState === Audio.PlayingState;
        if (currentTrackIndex < 0 || _currentPlaylistModel.count === 0) {
            playRetryTimer.stop();
            mainView._ignorePlaylistChange = true;
            playerPlaylist.clear();
            mainView._ignorePlaylistChange = false;
            if (globalPlayer) globalPlayer.stop();
            return;
        }
        rebuildPlayerPlaylist(currentTrackIndex);
        if (wasPlaying) startPlayback();
    }

    function autoDownload(track) {
        if (!track || !track.id) return;
        if (DownloadMgr.isDownloaded(track.id)) return;
        addToDownloadQueue(track);
    }
    
    function addToDownloadQueue(trackObj) {
        if (!trackObj || !trackObj.id) return;
        if (DownloadMgr.isDownloaded(trackObj.id)) return;
        
        for (var i = 0; i < _downloadQueueModel.count; i++) {
            if (_downloadQueueModel.get(i).id === trackObj.id) return;
        }
        
        _downloadQueueModel.append({
            id: trackObj.id,
            title: trackObj.title || "Unknown",
            artist: trackObj.artist || "",
            album: trackObj.album || "",
            status: "queued",
            progress: 0.0
        });
        
        processDownloadQueue();
    }
    
    property bool _isDownloadingQueue: false
    
    function processDownloadQueue() {
        if (_isDownloadingQueue) return;
        if (_downloadQueueModel.count === 0) return;
        
        var nextIndex = -1;
        for (var i = 0; i < _downloadQueueModel.count; i++) {
            if (_downloadQueueModel.get(i).status === "queued") {
                nextIndex = i;
                break;
            }
        }
        
        if (nextIndex === -1) return;
        
        _isDownloadingQueue = true;
        var item = _downloadQueueModel.get(nextIndex);
        _downloadQueueModel.setProperty(nextIndex, "status", "downloading");
        
        DownloadMgr.downloadSong(mainView.serverUrl, mainView.sid, mainView.synotoken,
            item.id, item.title, item.artist,
            function(loaded, total) {
                if (total > 0) {
                    var p = loaded / total;
                    for (var j = 0; j < _downloadQueueModel.count; j++) {
                        if (_downloadQueueModel.get(j).id === item.id) {
                            _downloadQueueModel.setProperty(j, "progress", p);
                            if (mainView.currentTrack && mainView.currentTrack.id === item.id) {
                                mainView.downloadProgress = p;
                            }
                            break;
                        }
                    }
                }
            },
            function(ok, path, size, errCode) {
                if (mainView.currentTrack && mainView.currentTrack.id === item.id) {
                    mainView.downloadProgress = -1;
                }
                if (ok) {
                    Storage.setSetting("dl_title_" + item.id, item.title || "");
                    Storage.setSetting("dl_artist_" + item.id, item.artist || "");
                    Storage.setSetting("dl_album_" + item.id, item.album || i18n.tr("Downloaded Singles"));
                    DownloadMgr.downloadCover(mainView.serverUrl, mainView.sid, mainView.synotoken, item.id, function(coverOk, coverPath) {
                        mainView.downloadFinished();
                    });
                } else if (errCode) {
                    var handled = mainView.handleApiError({ code: errCode, message: i18n.tr("Download failed: %1").arg(item.title) }, function() {
                        mainView.addToDownloadQueue(item);
                    });
                    if (!handled) {
                        mainView.showToast(i18n.tr("Download failed: %1").arg(item.title), true, false);
                    }
                } else {
                    mainView.showToast(i18n.tr("Download failed: %1").arg(item.title), true, false);
                }
                
                for (var j = 0; j < _downloadQueueModel.count; j++) {
                    if (_downloadQueueModel.get(j).id === item.id) {
                        _downloadQueueModel.remove(j);
                        break;
                    }
                }
                
                _isDownloadingQueue = false;
                processDownloadQueue();
            }
        );
    }
    
    function nextTrack() {
        if (_currentPlaylistModel.count === 0) return;
        if (_playbackFailCount >= _currentPlaylistModel.count) {
            showToast(i18n.tr("Cannot play next track. Playlist failed."), true, false);
            _playbackFailCount = 0;
            return;
        }

        var nextIdx = currentTrackIndex + 1;
        if (shuffleMode) {
            nextIdx = Math.floor(Math.random() * _currentPlaylistModel.count);
        } else if (nextIdx >= _currentPlaylistModel.count) {
            if (repeatMode === 1) nextIdx = 0;
            else {
                _playbackFailCount = 0;
                return; // Stop at end
            }
        }
        playTrack(_currentPlaylistModel, nextIdx);
    }
    
    function prevTrack() {
        if (_currentPlaylistModel.count === 0) return;
        if (_playbackFailCount >= _currentPlaylistModel.count) {
            showToast(i18n.tr("Cannot play previous track."), true, false);
            _playbackFailCount = 0;
            return;
        }

        var prevIdx = currentTrackIndex - 1;
        if (prevIdx < 0) {
            if (repeatMode === 1) prevIdx = _currentPlaylistModel.count - 1;
            else prevIdx = 0;
        }
        playTrack(_currentPlaylistModel, prevIdx);
    }
    
    function addCategoryToQueue(categoryType, categoryName, albumArtist, playNext) {
        showLoading(i18n.tr("Fetching songs..."));
        var filters = {};
        if (categoryType === "album") {
            filters["album"] = categoryName;
            if (albumArtist) filters["album_artist"] = albumArtist;
        } else if (categoryType === "artist") {
            filters["artist"] = categoryName;
        } else if (categoryType === "composer") {
            filters["composer"] = categoryName;
        } else if (categoryType === "genre") {
            filters["genre"] = categoryName;
        } else if (categoryType === "folder") {
            filters["folder_id"] = categoryName;
        }
        
        SynoApi.getSongs(serverUrl, sid, synotoken, 0, 1000, filters, function(err, data) {
            hideLoading();
            if (err) {
                mainView.handleApiError(err, function() {
                    addCategoryToQueue(categoryType, categoryName, albumArtist, playNext);
                });
                return;
            }
            if (data && data.songs) {
                var insertIdx = (playNext && currentTrackIndex >= 0) ? currentTrackIndex + 1 : currentPlaylistModel.count;
                var coverUrl = SynoApi.getCoverUrl(serverUrl, sid, synotoken, categoryType, categoryName, albumArtist);
                
                for (var i = 0; i < data.songs.length; i++) {
                    var song = data.songs[i];
                    var title = song.title || "Unknown";
                    var artist = (song.additional && song.additional.song_tag) ? song.additional.song_tag.artist : "Unknown";
                    
                    var albumName = (song.additional && song.additional.song_tag && song.additional.song_tag.album) ? song.additional.song_tag.album : "";
                    if (!albumName && categoryType === "album") albumName = categoryName;

                    var songObj = {
                        title: title,
                        artist: artist,
                        id: song.id,
                        path: song.path,
                        coverUrl: coverUrl,
                        album: albumName
                    };
                    
                    if (playNext) {
                        currentPlaylistModel.insert(insertIdx + i, songObj);
                    } else {
                        currentPlaylistModel.append(songObj);
                    }
                }
            }
        });
    }
    
    function downloadCategory(categoryType, categoryName, albumArtist) {
        showLoading(i18n.tr("Fetching songs for download..."));
        var filters = {};
        if (categoryType === "album") {
            filters["album"] = categoryName;
            if (albumArtist) filters["album_artist"] = albumArtist;
        } else if (categoryType === "artist") {
            filters["artist"] = categoryName;
        } else if (categoryType === "composer") {
            filters["composer"] = categoryName;
        } else if (categoryType === "genre") {
            filters["genre"] = categoryName;
        } else if (categoryType === "folder") {
            filters["folder_id"] = categoryName;
        }
        
        SynoApi.getSongs(serverUrl, sid, synotoken, 0, 1000, filters, function(err, data) {
            hideLoading();
            if (err) {
                mainView.handleApiError(err, function() {
                    downloadCategory(categoryType, categoryName, albumArtist);
                });
                return;
            }
            if (data && data.songs) {
                var added = 0;
                for (var i = 0; i < data.songs.length; i++) {
                    var song = data.songs[i];
                    var title = song.title || "Unknown";
                    var artist = (song.additional && song.additional.song_tag && song.additional.song_tag.artist) ? song.additional.song_tag.artist : "Unknown";
                    var albumName = (song.additional && song.additional.song_tag && song.additional.song_tag.album) ? song.additional.song_tag.album : "";
                    if (!albumName && categoryType === "album") albumName = categoryName;
                    addToDownloadQueue({ id: song.id, title: title, artist: artist, album: albumName });
                    added++;
                }
                showToast(i18n.tr("Added %1 songs to download queue").arg(added), false, true);
            }
        });
    }
    
    function togglePlayPause() {
        if (_currentPlaylistModel.count === 0) return;

        if (playerPlaylist && playerPlaylist.itemCount > 0 && globalPlayer) {
            if (globalPlayer.playbackState === Audio.PlayingState) {
                playRetryTimer.stop();
                globalPlayer.pause();
            } else {
                startPlayback();
            }
            return;
        }

        var startIdx = currentTrackIndex >= 0 ? currentTrackIndex : 0;
        if (startIdx >= _currentPlaylistModel.count) startIdx = 0;
        playTrack(_currentPlaylistModel, startIdx);
    }
    
    Connections {
        target: globalPlayer
        onStatusChanged: {
            if (globalPlayer.status === Audio.EndOfMedia) {
                // media-hub advances the playlist on its own (or stops at the end)
                _playbackFailCount = 0;
            } else if (globalPlayer.status === Audio.InvalidMedia) {
                _playbackFailCount++;
                nextTrack();
            } else if (globalPlayer.status === Audio.Buffered || globalPlayer.status === Audio.Loaded) {
                _playbackFailCount = 0;
            }
        }
        onError: {
            // media-hub service went away: recreate the player to get a fresh
            // session once the service is back.
            if (globalPlayer.error === Audio.ServiceMissing) {
                mainView.recreatePlayer();
            }
        }
    }
    
    function pushPage(url, properties) {
        pageStack.push(url, properties);
    }

    function savePlaylist() {
        var items = [];
        for (var i = 0; i < _currentPlaylistModel.count; i++) {
            var item = _currentPlaylistModel.get(i);
            if (item.id) {
                items.push({
                    title: item.title || "",
                    artist: item.artist || "",
                    id: item.id || "",
                    path: item.path || "",
                    coverUrl: item.coverUrl || ""
                });
            }
        }
        var state = {
            items: items,
            index: currentTrackIndex,
            repeat: repeatMode,
            shuffle: shuffleMode,
            position: globalPlayer ? (globalPlayer.position || 0) : 0
        };
        Storage.setSetting("playlist_state", JSON.stringify(state));
    }

    function restorePlaylist() {
        try {
            var raw = Storage.getSetting("playlist_state", "");
            if (!raw) return;
            var state = JSON.parse(raw);
            if (!state || !state.items || state.items.length === 0) {
                Storage.setSetting("playlist_state", "");
                return;
            }

            _currentPlaylistModel.clear();
            for (var j = 0; j < state.items.length; j++) {
                if (state.items[j].id) _currentPlaylistModel.append(state.items[j]);
            }
            if (_currentPlaylistModel.count === 0) {
                Storage.setSetting("playlist_state", "");
                return;
            }
            currentTrackIndex = state.index >= 0 && state.index < _currentPlaylistModel.count ? state.index : -1;
            repeatMode = state.repeat || 0;
            shuffleMode = state.shuffle || false;

            if (currentTrackIndex >= 0) {
                var trk = _currentPlaylistModel.get(currentTrackIndex);
                currentTrack = {
                    title: trk.title || "",
                    artist: trk.artist || "",
                    id: trk.id || "",
                    path: trk.path || "",
                    coverUrl: trk.coverUrl || ""
                };
            }
        } catch(e) {
            Storage.setSetting("playlist_state", "");
        }
    }

    PageStack {
        id: pageStack
        anchors.fill: parent
    }

    // Global Synology Loading Modal Popup
    LoadingOverlay {
        id: loadingOverlay
    }

    // Global Alert / Error Dialog
    SynoDialog {
        id: synoDialog
    }

    // Global Notification Toast
    NotificationBanner {
        id: notificationBanner
    }

    Component.onCompleted: {
        loadVersion();
        Storage.initDb();
        checkSession();
        restorePlaylist();
        applyPlaybackMode();
    }

    function loadVersion() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../manifest.json"));
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var manifest = JSON.parse(xhr.responseText);
                    if (manifest.version) {
                        mainView.appVersion = manifest.version;
                    }
                } catch (e) {
                    console.warn("Failed to parse manifest.json:", e);
                }
            }
        }
        xhr.send();
    }

    function checkSession() {
        var savedUrl = Storage.getSetting("serverUrl", "");
        var savedSid = Storage.getSetting("sid", "");
        var savedToken = Storage.getSetting("synotoken", "");
        var savedUser = Storage.getSetting("username", "");

        var savedHttps = Storage.getSetting("https", "true") === "true";
        var cleanServer = savedUrl.replace(/^https?:\/\//i, "");
        var fullUrl = (savedHttps ? "https://" : "http://") + cleanServer;

        if (savedUrl && savedSid) {
            mainView.serverUrl = fullUrl;
            mainView.sid = savedSid;
            mainView.synotoken = savedToken;
            mainView.username = savedUser;
            mainView.isLoggedIn = true;
            pageStack.push(Qt.resolvedUrl("pages/MainTabsPage.qml"));
        } else {
            pageStack.push(Qt.resolvedUrl("pages/LoginPage.qml"));
        }
    }

    function showLoading(msg) {
        mainView.loading = true;
        loadingOverlay.show(msg);
    }

    function hideLoading() {
        mainView.loading = false;
        loadingOverlay.hide();
    }

    function handleApiError(err, retryFn) {
        if (!err) return false;

        // 1. Auth / session errors → force re-login
        var authCodes = [105, 106, 107, 119, 400, 401, 402, 403, 404, 405, 406, 407, 408];
        if (authCodes.indexOf(err.code) !== -1) {
            mainView.isLoggedIn = false;
            mainView.sid = "";
            mainView.synotoken = "";
            Storage.setSetting("sid", "");
            Storage.setSetting("synotoken", "");
            Storage.clearLibraryCache();
            mainView.showErrorDialog(i18n.tr("Session Expired"),
                err.message || i18n.tr("Your session has expired. Please log in again."),
                i18n.tr("Log In"), null,
                function() {
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("pages/LoginPage.qml"));
                });
            return true;
        }

        // 2. Server unavailable / network errors → Retry (+ recommend Offline Mode)
        var networkCodes = [0, -1, -2];
        var isUnavailable = networkCodes.indexOf(err.code) !== -1 ||
                            (typeof err.code === "number" && err.code >= 500 && err.code < 600);
        if (isUnavailable) {
            var hasDownloads = DownloadMgr.getDownloadedSongsList().length > 0;
            if (hasDownloads) {
                mainView.showErrorDialog(i18n.tr("Server Unavailable"),
                    (err.message || i18n.tr("The server is currently unavailable. Please try again.")) + "\n\n" +
                    i18n.tr("You can switch to Offline Mode and listen to your downloaded music."),
                    i18n.tr("Offline Mode"), i18n.tr("Retry"),
                    function() {
                        mainView.isOfflineMode = true;
                        pageStack.clear();
                        pageStack.push(Qt.resolvedUrl("pages/MainTabsPage.qml"));
                    },
                    function() {
                        if (retryFn) retryFn();
                    });
            } else {
                mainView.showErrorDialog(i18n.tr("Server Unavailable"),
                    err.message || i18n.tr("The server is currently unavailable. Please try again."),
                    i18n.tr("Retry"), null,
                    function() {
                        if (retryFn) retryFn();
                    });
            }
            return true;
        }

        mainView.showToast(err.message || i18n.tr("Server error"), true, false);
        return false;
    }

    function showErrorDialog(title, message, btnText, cancelText, onOk, onCancel) {
        synoDialog.show(title, message, btnText, cancelText, onOk, onCancel);
    }

    function showToast(msg, isError, isSuccess) {
        notificationBanner.show(msg, isError, isSuccess);
    }

    function showNotification(msg, type) {
        showToast(msg, type === "error", type === "success" || type === "info");
    }
    
    function showInputDialog(title, placeholder, okText, cancelText, onOk) {
        synoInputDialog.show(title, placeholder, okText, cancelText, onOk);
    }
    
    SynoInputDialog {
        id: synoInputDialog
    }
}
