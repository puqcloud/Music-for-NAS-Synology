import QtQuick 2.9
import Ubuntu.Components 1.3
import "../components"
import "../js/Theme.js" as Theme
import "../js/DownloadManager.js" as DownloadMgr
import "../js/Storage.js" as Storage

Page {
    id: offlineAlbumsPage
    header: SynoHeader {
        id: pageHeader
        title: i18n.tr("Offline Albums")
        showBack: false
    }

    Rectangle {
        anchors.top: pageHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Theme.background

        Label {
            anchors.centerIn: parent
            text: i18n.tr("No albums downloaded.")
            color: Theme.textMuted
            font.pixelSize: units.gu(1.6)
            visible: albumsModel.count === 0 && !loading
        }

        ListView {
            id: listView
            anchors.fill: parent
            model: albumsModel
            clip: true
            
            delegate: Item {
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
                    color: Theme.primaryLight
                    radius: units.gu(0.5)
                    clip: true
                    
                    Icon {
                        name: "media-optical"
                        anchors.centerIn: parent
                        color: "white"
                        width: units.gu(3)
                        height: units.gu(3)
                        visible: albumCoverImage.status !== Image.Ready
                    }
                    
                    Image {
                        id: albumCoverImage
                        anchors.fill: parent
                        source: model.coverPath
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                
                Column {
                    anchors.left: coverRect.right
                    anchors.leftMargin: units.gu(1.5)
                    anchors.right: menuIconItem.left
                    anchors.rightMargin: units.gu(1.5)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Label {
                        text: model.albumName
                        font.weight: Font.Bold
                        font.pixelSize: units.gu(2.2)
                        color: Theme.textDark
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    
                    Label {
                        text: model.albumArtist || i18n.tr("%1 songs").arg(model.songCount)
                        font.pixelSize: units.gu(1.6)
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        width: parent.width
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
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            color: Theme.textMuted
                            anchors.centerIn: parent
                        }
                    }
                    
                    MouseArea {
                        id: menuArea
                        anchors.fill: parent
                        onClicked: {
                            actionSheet.albumName = model.albumName
                            actionSheet.open()
                        }
                    }
                }
                
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: menuIconItem.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("OfflineAlbumSongsPage.qml"), { albumName: model.albumName })
                    }
                }
            }
        }

        Scrollbar {
            flickableItem: listView
            align: Qt.AlignTrailing
        }
    }
    BottomSheet {
        id: actionSheet
        
        property string albumName: ""
        
        content: Column {
            width: parent.width
            
            Item {
                width: parent.width
                height: units.gu(6)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(2)
                    spacing: units.gu(2)
                    Icon {
                        name: "media-playback-start"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: i18n.tr("Play All")
                        font.pixelSize: units.gu(2)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var songs = getAlbumSongs(actionSheet.albumName);
                        if (songs.length > 0) {
                            mainView.playTrack(songs, 0);
                            mainView.showToast(i18n.tr("Playing album"), false, true);
                        }
                        actionSheet.close();
                    }
                }
            }
            
            Rectangle { width: parent.width; height: units.dp(1); color: Theme.divider }
            
            Item {
                width: parent.width
                height: units.gu(6)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(2)
                    spacing: units.gu(2)
                    Icon {
                        name: "add"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: i18n.tr("Add All to Queue")
                        font.pixelSize: units.gu(2)
                        color: Theme.textDark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var songs = getAlbumSongs(actionSheet.albumName);
                        for (var i = 0; i < songs.length; i++) {
                            mainView.currentPlaylistModel.append(songs[i]);
                        }
                        if (songs.length > 0) {
                            mainView.showToast(i18n.tr("Added album to queue"), false, true);
                        }
                        actionSheet.close();
                    }
                }
            }
            
            Rectangle { width: parent.width; height: units.dp(1); color: Theme.divider }
            
            Item {
                width: parent.width
                height: units.gu(6)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(2)
                    spacing: units.gu(2)
                    Icon {
                        name: "delete"
                        width: units.gu(2.4)
                        height: units.gu(2.4)
                        color: Theme.redCategory
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: i18n.tr("Delete Album from Device")
                        font.pixelSize: units.gu(2)
                        color: Theme.redCategory
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var songs = getAlbumSongs(actionSheet.albumName);
                        for (var i = 0; i < songs.length; i++) {
                            DownloadMgr.deleteDownloadedSong(songs[i].id);
                        }
                        loadAlbums();
                        mainView.onDownloadsChanged();
                        mainView.showToast(i18n.tr("Album deleted"), false, true);
                        actionSheet.close();
                    }
                }
            }
        }
    }
    ListModel {
        id: albumsModel
    }
    
    property bool loading: false

    function getAlbumSongs(albumName) {
        var arr = [];
        var list = DownloadMgr.getDownloadedSongsList();
        for (var i = 0; i < list.length; i++) {
            var songId = list[i].id;
            var storedAlbum = Storage.getSetting("dl_album_" + songId, i18n.tr("Downloaded Singles"));
            if (storedAlbum === albumName) {
                var cover = DownloadMgr.hasCover(songId) ? ("file://" + DownloadMgr.getCoverPath(songId)) : "";
                arr.push({
                    id: songId,
                    title: Storage.getSetting("dl_title_" + songId, "Song " + songId),
                    artist: Storage.getSetting("dl_artist_" + songId, "Unknown"),
                    path: list[i].path,
                    coverUrl: cover
                });
            }
        }
        return arr;
    }

    function loadAlbums() {
        loading = true;
        albumsModel.clear();
        
        var list = DownloadMgr.getDownloadedSongsList();
        var albumCounts = {};
        var albumCovers = {};
        var albumArtists = {};
        
        for (var i = 0; i < list.length; i++) {
            var songId = list[i].id;
            var storedAlbum = Storage.getSetting("dl_album_" + songId, i18n.tr("Downloaded Singles"));
            
            if (albumCounts[storedAlbum]) {
                albumCounts[storedAlbum]++;
            } else {
                albumCounts[storedAlbum] = 1;
                albumArtists[storedAlbum] = Storage.getSetting("dl_artist_" + songId, "");
            }
            
            if (!albumCovers[storedAlbum] && DownloadMgr.hasCover(songId)) {
                albumCovers[storedAlbum] = "file://" + DownloadMgr.getCoverPath(songId);
            }
        }
        
        for (var album in albumCounts) {
            albumsModel.append({
                albumName: album,
                songCount: albumCounts[album],
                coverPath: albumCovers[album] || "",
                albumArtist: albumArtists[album] || ""
            });
        }
        
        loading = false;
    }

    Component.onCompleted: loadAlbums()
    
    Connections {
        target: mainView
        onDownloadFinished: loadAlbums()
        onCacheCleared: loadAlbums()
    }
}
