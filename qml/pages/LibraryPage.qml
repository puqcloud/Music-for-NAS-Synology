import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../js/Theme.js" as Theme
import "../js/SynologyApi.js" as SynoApi
import "../js/DownloadManager.js" as DownloadMgr
import "../js/Storage.js" as Storage

Page {
    id: libraryPage

    property int currentTabIndex: 0
    property var tabNames: ["ALBUMS", "ARTISTS", "COMPOSERS", "GENRES", "FOLDERS", "ALL SONGS"]

    header: SynoHeader {
        id: pageHeader
        title: i18n.tr("Library")
        showBack: false
        showSearch: false
        showAdd: currentTabIndex === 5 && listModel.count > 0
        showMore: false
        onAddClicked: { addAllToQueue(); }
    }
    
    Rectangle {
        anchors.top: pageHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Theme.background
        
        // Scrollable Tabs
        ListView {
            id: tabsList
            height: units.gu(6)
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            orientation: ListView.Horizontal
            model: tabNames
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            
            delegate: Item {
                width: Math.max(tabsList.width / 3.5, tabLabel.paintedWidth + units.gu(4))
                height: tabsList.height
                
                Label {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData
                    color: currentTabIndex === index ? Theme.primary : Theme.textMuted
                    font.weight: currentTabIndex === index ? Font.DemiBold : Font.Normal
                    fontSize: "small"
                }
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: units.dp(3)
                    color: Theme.primary
                    visible: currentTabIndex === index
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        currentTabIndex = index;
                        loadData();
                    }
                }
            }
        }
        
        Rectangle {
            id: divider
            anchors.top: tabsList.bottom
            width: parent.width
            height: units.dp(1)
            color: Theme.divider
        }
        
        ListView {
            id: listView
            anchors.top: divider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            model: listModel
            delegate: libraryDelegate
            clip: true
        }

        Scrollbar {
            flickableItem: listView
            align: Qt.AlignTrailing
        }
        
        ListModel {
            id: listModel
        }
        
        Component {
            id: libraryDelegate
            Item {
                width: listView.width
                height: units.gu(8)
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: units.dp(1)
                    color: Theme.divider
                }
                
                Rectangle {
                    id: coverRect
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1)
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(6)
                    height: units.gu(6)
                    color: "#E0E0E0"
                    radius: units.gu(0.5)
                    clip: true
                    
                    Icon {
                        name: currentTabIndex === 1 ? "contact" : (currentTabIndex === 5 ? "audio-x-generic" : "folder")
                        anchors.centerIn: parent
                        color: Theme.textMuted
                        width: units.gu(3)
                        height: units.gu(3)
                    }
                    
                    Image {
                        id: coverImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: model.coverUrl || ""
                    }
                }
                
                Column {
                    anchors.left: coverRect.right
                    anchors.leftMargin: units.gu(1.5)
                    anchors.right: menuIconItem.left
                    anchors.rightMargin: units.gu(1.5)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Label {
                        text: model.title
                        font.weight: Font.Bold
                        font.pixelSize: units.gu(2.2)
                        color: Theme.textDark
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Label {
                        text: model.subtitle
                        font.pixelSize: units.gu(1.6)
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        width: parent.width
                        visible: model.subtitle !== ""
                    }
                }
                
                Item {
                    id: menuIconItem
                    width: units.gu(6)
                    height: parent.height
                    anchors.right: parent.right
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: units.gu(4.5)
                        height: units.gu(4.5)
                        radius: units.gu(2.25)
                        color: menuArea.pressed ? "#E5E5EA" : "transparent"
                        
                        Icon {
                            name: "navigation-menu"
                            width: units.gu(2.8)
                            height: units.gu(2.8)
                            color: Theme.textDark
                            anchors.centerIn: parent
                        }
                    }

                    MouseArea {
                        id: menuArea
                        anchors.fill: parent
                        z: 10
                        onClicked: {
                            var catType = "";
                            var catName = model.title;
                            var albArtist = "";
                            if (currentTabIndex === 0) { catType = "album"; albArtist = model.subtitle; }
                            else if (currentTabIndex === 1) catType = "artist";
                            else if (currentTabIndex === 2) catType = "composer";
                            else if (currentTabIndex === 3) catType = "genre";
                            else if (currentTabIndex === 4) { catType = "folder"; catName = model.id; }
                            else if (currentTabIndex === 5) { catType = "song"; }
                            
                            var actionData = {
                                catType: catType,
                                catName: catName,
                                albArtist: albArtist,
                                song: (catType === "song") ? { title: model.title, artist: model.subtitle, id: model.id, path: model.path, coverUrl: model.coverUrl, album: model.album } : null
                            };
                            actionSheet.itemData = actionData;
                            actionSheet.open();
                        }
                    }
                }
                
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: menuIconItem.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    onClicked: {
                        if (currentTabIndex === 5) {
                            // All songs -> Play directly
                            var track = { title: model.title, artist: model.subtitle, id: model.id, path: model.path, coverUrl: model.coverUrl };
                            mainView.playTrack([track], 0);
                        } else {
                            // Open AlbumSongsPage for the selected category
                            var catType = "";
                            var catName = model.title;
                            var albArtist = "";
                            if (currentTabIndex === 0) { catType = "album"; albArtist = model.subtitle; }
                            else if (currentTabIndex === 1) catType = "artist";
                            else if (currentTabIndex === 2) catType = "composer";
                            else if (currentTabIndex === 3) catType = "genre";
                            else if (currentTabIndex === 4) { catType = "folder"; catName = model.id; } // for folder, we pass ID
                            
                            pageStack.push(Qt.resolvedUrl("AlbumSongsPage.qml"), {
                                categoryType: catType,
                                categoryName: catName,
                                albumArtist: albArtist
                            });
                        }
                    }
                }
            }
        }
    }
    
    BottomSheet {
        id: actionSheet
        property var itemData: null
        contentHeight: actionColumn.height + units.gu(4)
        
        Column {
            id: actionColumn
            width: parent.width
            
            Rectangle {
                width: parent.width
                height: units.gu(6)
                color: playMouse.pressed ? Theme.divider : "transparent"
                visible: actionSheet.itemData && actionSheet.itemData.song
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(1)
                    spacing: units.gu(2)
                    Icon {
                        name: "media-playback-start"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: i18n.tr("Play")
                        font.pixelSize: units.gu(2)
                        color: Theme.primary
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    onClicked: {
                        if (actionSheet.itemData && actionSheet.itemData.song) {
                            mainView.playTrack([actionSheet.itemData.song], 0);
                        }
                        actionSheet.close();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: units.dp(1)
                color: Theme.divider
                visible: actionSheet.itemData && actionSheet.itemData.song
            }

            Rectangle {
                width: parent.width
                height: units.gu(6)
                color: addMouse.pressed ? Theme.divider : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(1)
                    spacing: units.gu(2)
                    Icon {
                        name: "add"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: i18n.tr("Add to Queue")
                        font.pixelSize: units.gu(2)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    onClicked: {
                        if (actionSheet.itemData) {
                            if (actionSheet.itemData.catType === "song") {
                                mainView.currentPlaylistModel.append(actionSheet.itemData.song);
                            } else {
                                mainView.addCategoryToQueue(actionSheet.itemData.catType, actionSheet.itemData.catName, actionSheet.itemData.albArtist, false);
                            }
                        }
                        actionSheet.close();
                    }
                }
            }
            
            Rectangle {
                width: parent.width
                height: units.dp(1)
                color: Theme.divider
            }
            
            Rectangle {
                width: parent.width
                height: units.gu(6)
                color: playNextMouse.pressed ? Theme.divider : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(1)
                    spacing: units.gu(2)
                    Icon {
                        name: "media-playback-start"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: i18n.tr("Play Next")
                        font.pixelSize: units.gu(2)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: playNextMouse
                    anchors.fill: parent
                    onClicked: {
                        if (actionSheet.itemData) {
                            if (actionSheet.itemData.catType === "song") {
                                var insertIdx = mainView.currentTrackIndex >= 0 ? mainView.currentTrackIndex + 1 : 0;
                                mainView.currentPlaylistModel.insert(insertIdx, actionSheet.itemData.song);
                            } else {
                                mainView.addCategoryToQueue(actionSheet.itemData.catType, actionSheet.itemData.catName, actionSheet.itemData.albArtist, true);
                            }
                        }
                        actionSheet.close();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: units.gu(6)
                color: downloadMouse.pressed ? Theme.divider : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(1)
                    spacing: units.gu(2)
                    Icon {
                        name: "document-save"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: (actionSheet.itemData && actionSheet.itemData.song && DownloadMgr.isDownloaded(actionSheet.itemData.song.id)) ? i18n.tr("Saved") : i18n.tr("Download")
                        font.pixelSize: units.gu(2)
                        color: (actionSheet.itemData && actionSheet.itemData.song && DownloadMgr.isDownloaded(actionSheet.itemData.song.id)) ? Theme.primary : Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: downloadMouse
                    anchors.fill: parent
                    onClicked: {
                        if (actionSheet.itemData) {
                            if (actionSheet.itemData.catType === "song") {
                                var s = actionSheet.itemData.song;
                                if (DownloadMgr.isDownloaded(s.id)) {
                                    actionSheet.close();
                                    return;
                                }
                                mainView.addToDownloadQueue(s);
                                mainView.showToast(i18n.tr("Added to download queue"), false, true);
                            } else {
                                mainView.downloadCategory(actionSheet.itemData.catType, actionSheet.itemData.catName, actionSheet.itemData.albArtist);
                            }
                        }
                        actionSheet.close();
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        loadData();
    }

    function addAllToQueue() {
        if (currentTabIndex === 5) {
            for (var i = 0; i < listModel.count; i++) {
                var item = listModel.get(i);
                mainView.currentPlaylistModel.append({
                    title: item.title,
                    artist: item.subtitle,
                    id: item.id,
                    path: item.path,
                    coverUrl: item.coverUrl,
                    album: item.album
                });
            }
            mainView.showToast(i18n.tr("%1 songs added to queue").arg(listModel.count), false, true);
        } else {
            var count = 0;
            for (var j = 0; j < listModel.count; j++) {
                var cat = listModel.get(j);
                mainView.currentPlaylistModel.append({
                    title: cat.title,
                    artist: cat.subtitle || "",
                    id: cat.id || "",
                    path: cat.path || "",
                    coverUrl: cat.coverUrl || ""
                });
                count++;
            }
            mainView.showToast(i18n.tr("%1 items added to queue. Tap to play.").arg(count), false, true);
        }
    }
    
    function loadData() {
        if (!mainView.sid) return;
        
        var cacheKey = "lib_cache_" + currentTabIndex;
        var cached = Storage.getSetting(cacheKey, "");
        if (cached) {
            try {
                var cachedItems = JSON.parse(cached);
                listModel.clear();
                for (var ci = 0; ci < cachedItems.length; ci++) {
                    listModel.append(cachedItems[ci]);
                }
            } catch(e) {}
        }

        mainView.showLoading(i18n.tr("Loading..."));
        
        var cb = function(err, data) {
            mainView.hideLoading();
            if (err) {
                mainView.handleApiError(err, function() {
                    libraryPage.loadData();
                });
                return;
            }
            if (data) {
                listModel.clear();
                var items = [];
                if (currentTabIndex === 0 && data.albums) items = data.albums;
                else if (currentTabIndex === 1 && data.artists) items = data.artists;
                else if (currentTabIndex === 2 && data.composers) items = data.composers;
                else if (currentTabIndex === 3 && data.genres) items = data.genres;
                else if (currentTabIndex === 4 && data.folders) items = data.folders;
                else if (currentTabIndex === 5 && data.songs) items = data.songs;
                
                var toCache = [];
                for (var i = 0; i < items.length; i++) {
                    var item = items[i];
                    var title = "Unknown";
                    var subtitle = "";
                    var id = "";
                    var path = "";
                    var album = "";
                    var coverUrl = "";
                    
                    if (currentTabIndex === 0) {
                        title = item.name;
                        subtitle = item.album_artist || "";
                        coverUrl = SynoApi.getCoverUrl(mainView.serverUrl, mainView.sid, mainView.synotoken, "album", item.name, item.album_artist);
                    } else if (currentTabIndex === 1) {
                        title = item.name;
                        coverUrl = SynoApi.getCoverUrl(mainView.serverUrl, mainView.sid, mainView.synotoken, "artist", item.name, "");
                    } else if (currentTabIndex === 2) {
                        title = item.name;
                        coverUrl = SynoApi.getCoverUrl(mainView.serverUrl, mainView.sid, mainView.synotoken, "composer", item.name, "");
                    } else if (currentTabIndex === 3) {
                        title = item.name;
                    } else if (currentTabIndex === 4) {
                        title = item.title || item.name;
                        id = item.id;
                    } else if (currentTabIndex === 5) {
                        title = item.title;
                        subtitle = (item.additional && item.additional.song_tag && item.additional.song_tag.artist) ? item.additional.song_tag.artist : "Unknown";
                        id = item.id;
                        path = item.path;
                        album = (item.additional && item.additional.song_tag && item.additional.song_tag.album) ? item.additional.song_tag.album : "";
                        var albumArtist = (item.additional && item.additional.song_tag && item.additional.song_tag.album_artist) ? item.additional.song_tag.album_artist : "";
                        coverUrl = album ? SynoApi.getCoverUrl(mainView.serverUrl, mainView.sid, mainView.synotoken, "album", album, albumArtist) : "";
                    }
                    
                    var row = {
                        title: title,
                        subtitle: subtitle,
                        id: id,
                        path: path,
                        coverUrl: coverUrl,
                        album: album
                    };
                    listModel.append(row);
                    toCache.push(row);
                }
                
                Storage.setSetting(cacheKey, JSON.stringify(toCache));
            }
        };

        if (currentTabIndex === 0) SynoApi.getAlbums(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, cb);
        else if (currentTabIndex === 1) SynoApi.getArtists(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, cb);
        else if (currentTabIndex === 2) SynoApi.getComposers(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, cb);
        else if (currentTabIndex === 3) SynoApi.getGenres(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, cb);
        else if (currentTabIndex === 4) SynoApi.getFolders(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, cb);
        else if (currentTabIndex === 5) SynoApi.getSongs(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, null, cb);
    }
}
