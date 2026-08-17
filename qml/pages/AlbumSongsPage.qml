import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../js/Theme.js" as Theme
import "../js/SynologyApi.js" as SynoApi
import "../js/DownloadManager.js" as DownloadMgr
import "../js/Storage.js" as Storage

Page {
    id: albumSongsPage
    
    property string categoryType: "" // e.g. "album", "artist", "composer", "genre", "folder"
    property string categoryName: ""
    property string albumArtist: ""
    
    header: SynoHeader {
        id: pageHeader
        title: categoryName || i18n.tr("Songs")
        showBack: true
        onBackClicked: pageStack.pop()
    }
    
    Rectangle {
        anchors.top: pageHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Theme.background
        
        ListView {
            id: listView
            anchors.fill: parent
            model: listModel
            delegate: songDelegate
            clip: true
            
            header: Component {
                Item {
                    width: listView.width
                    height: units.gu(16)
                    visible: categoryType === "album" || categoryType === "artist"
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        
                        Image {
                            anchors.fill: parent
                            source: coverUrl
                            fillMode: Image.PreserveAspectCrop
                            opacity: 0.4
                        }
                    }
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: units.gu(2)
                        spacing: units.gu(2)
                        
                        Rectangle {
                            width: units.gu(12)
                            height: units.gu(12)
                            color: Theme.primaryLight
                            radius: units.gu(0.5)
                            clip: true
                            
                            Icon {
                                name: "media-optical"
                                anchors.centerIn: parent
                                color: Theme.background
                                width: units.gu(4)
                                height: units.gu(4)
                                visible: headerCoverImage.status !== Image.Ready
                            }
                            
                            Image {
                                id: headerCoverImage
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: coverUrl
                            }
                        }
                        
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(16)
                            spacing: units.gu(0.5)
                            
                            Label {
                                text: categoryName
                                font.weight: Font.Bold
                                font.pixelSize: units.gu(2.4)
                                color: "white"
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                            }
                            Label {
                                text: albumArtist
                                font.pixelSize: units.gu(1.8)
                                color: "#EEEEEE"
                                elide: Text.ElideRight
                                width: parent.width
                                visible: albumArtist !== ""
                            }
                            Label {
                                text: listModel.count + " " + i18n.tr("song(s)")
                                font.pixelSize: units.gu(1.6)
                                color: "#CCCCCC"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }
        
        Scrollbar {
            flickableItem: listView
            align: Qt.AlignTrailing
        }

        ListModel {
            id: listModel
        }
        
        Component {
            id: songDelegate
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
                    color: Theme.divider
                    radius: units.gu(0.5)
                    clip: true
                    
                    Icon {
                        name: "audio-x-generic"
                        anchors.centerIn: parent
                        color: Theme.textMuted
                        width: units.gu(3)
                        height: units.gu(3)
                    }
                    
                    Image {
                        id: trackCoverImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: coverUrl || ""
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
                        font.pixelSize: units.gu(2)
                        color: Theme.textDark
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Label {
                        text: model.artist
                        font.pixelSize: units.gu(1.6)
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        width: parent.width
                        visible: model.artist !== ""
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
                            var songData = {
                                title: model.title,
                                artist: model.artist,
                                id: model.id,
                                path: model.path,
                                coverUrl: coverUrl,
                                album: model.album
                            };
                            actionSheet.songItem = songData;
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
                        var playlist = [];
                        for (var i = 0; i < listModel.count; i++) {
                            var item = listModel.get(i);
                            playlist.push({ title: item.title, artist: item.artist, id: item.id, path: item.path, coverUrl: coverUrl, album: item.album });
                        }
                        mainView.playTrack(playlist, index);
                    }
                }
            }
        }
    }
    
    BottomSheet {
        id: actionSheet
        property var songItem: null
        contentHeight: actionColumn.height + units.gu(4)
        
        Column {
            id: actionColumn
            width: parent.width
            
            Rectangle {
                width: parent.width
                height: units.gu(6)
                color: playMouse.pressed ? Theme.divider : "transparent"
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
                        if (actionSheet.songItem) {
                            mainView.playTrack([actionSheet.songItem], 0);
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
                        if (actionSheet.songItem) {
                            mainView.currentPlaylistModel.append(actionSheet.songItem);
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
                        if (actionSheet.songItem) {
                            var insertIdx = mainView.currentTrackIndex >= 0 ? mainView.currentTrackIndex + 1 : 0;
                            mainView.currentPlaylistModel.insert(insertIdx, actionSheet.songItem);
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
                        text: (actionSheet.songItem && DownloadMgr.isDownloaded(actionSheet.songItem.id)) ? i18n.tr("Downloaded") : i18n.tr("Download")
                        font.pixelSize: units.gu(2)
                        color: (actionSheet.songItem && DownloadMgr.isDownloaded(actionSheet.songItem.id)) ? Theme.primary : Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: downloadMouse
                    anchors.fill: parent
                    onClicked: {
                        if (actionSheet.songItem) {
                            var s = actionSheet.songItem;
                            if (DownloadMgr.isDownloaded(s.id)) {
                                actionSheet.close();
                                return;
                            }
                            mainView.addToDownloadQueue(s);
                            mainView.showToast(i18n.tr("Added to download queue"), false, true);
                        }
                        actionSheet.close();
                    }
                }
            }
        }
    }
    
    property string coverUrl: ""
    
    Component.onCompleted: {
        coverUrl = SynoApi.getCoverUrl(mainView.serverUrl, mainView.sid, mainView.synotoken, categoryType, categoryName, albumArtist);
        loadSongs();
    }
    
    function loadSongs() {
        if (!mainView.sid) return;
        mainView.showLoading();
        
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
            filters["folder_id"] = categoryName; // if folder, categoryName is ID
        }
        
        SynoApi.getSongs(mainView.serverUrl, mainView.sid, mainView.synotoken, 0, 1000, filters, function(err, data) {
            mainView.hideLoading();
            if (err) {
                mainView.handleApiError(err, function() {
                    albumSongsPage.loadSongs();
                });
                return;
            }
            listModel.clear();
            if (data && data.songs) {
                for (var i = 0; i < data.songs.length; i++) {
                    var song = data.songs[i];
                    var title = song.title || "Unknown";
                    var artist = (song.additional && song.additional.song_tag) ? song.additional.song_tag.artist : "Unknown";
                    var realAlbum = (song.additional && song.additional.song_tag && song.additional.song_tag.album) ? song.additional.song_tag.album : "";
                    if (!realAlbum && categoryType === "album") realAlbum = categoryName;

                    listModel.append({
                        title: title,
                        artist: artist,
                        id: song.id,
                        path: song.path,
                        album: realAlbum
                    });
                }
            }
        });
    }
}
