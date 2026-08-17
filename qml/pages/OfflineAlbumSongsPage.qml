import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../js/Theme.js" as Theme
import "../js/DownloadManager.js" as DownloadMgr
import "../js/Storage.js" as Storage

Page {
    id: offlineAlbumSongsPage
    property string albumName: ""
    
    header: SynoHeader {
        id: pageHeader
        title: albumName
        showBack: true
        showPlayAll: listModel.count > 0
        showAddAll: listModel.count > 0
        
        onBackClicked: pageStack.pop()
        
        onPlayAllClicked: {
            if (listModel.count === 0) return;
            var arr = [];
            for (var i = 0; i < listModel.count; i++) {
                var it = listModel.get(i);
                arr.push({
                    title: it.title,
                    artist: it.artist,
                    id: it.id,
                    path: it.path,
                    coverUrl: it.coverPath || ""
                });
            }
            mainView.playTrack(arr, 0);
            mainView.showToast(i18n.tr("Playing album"), false, true);
        }
        
        onAddAllClicked: {
            if (listModel.count === 0) return;
            for (var i = 0; i < listModel.count; i++) {
                var it = listModel.get(i);
                mainView.currentPlaylistModel.append({
                    title: it.title,
                    artist: it.artist,
                    id: it.id,
                    path: it.path,
                    coverUrl: it.coverPath || ""
                });
            }
            mainView.showToast(i18n.tr("Added album to queue"), false, true);
        }
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
                    color: Theme.primaryLight
                    radius: units.gu(0.5)

                    Icon {
                        name: "audio-x-generic"
                        anchors.centerIn: parent
                        color: "#ffffff"
                        width: units.gu(3)
                        height: units.gu(3)
                        visible: trackCoverImage.status !== Image.Ready
                    }
                    
                    Image {
                        id: trackCoverImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: model.coverPath
                    }
                }

                Column {
                    anchors.left: coverRect.right
                    anchors.leftMargin: units.gu(1.5)
                    anchors.right: menuIconItem.left
                    anchors.rightMargin: units.gu(1.5)
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        text: model.title || "Unknown"
                        font.weight: Font.Bold
                        font.pixelSize: units.gu(2)
                        color: Theme.textDark
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Label {
                        text: (model.artist || "Unknown") + " • " + model.sizeText
                        font.pixelSize: units.gu(1.5)
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
                            actionSheet.songId = model.id;
                            actionSheet.songTitle = model.title;
                            actionSheet.songArtist = model.artist;
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
                        var arr = [];
                        for (var i = 0; i < listModel.count; i++) {
                            var it = listModel.get(i);
                            arr.push({
                                title: it.title,
                                artist: it.artist,
                                id: it.id,
                                path: it.path,
                                coverUrl: it.coverPath || ""
                            });
                        }
                        mainView.playTrack(arr, index);
                    }
                }
            }
        }
        
        BottomSheet {
            id: actionSheet
            property string songId: ""
            property string songTitle: ""
            property string songArtist: ""
            
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
                            var cover = DownloadMgr.hasCover(actionSheet.songId) ? ("file://" + DownloadMgr.getCoverPath(actionSheet.songId)) : "";
                            mainView.playTrack([{
                                title: actionSheet.songTitle,
                                artist: actionSheet.songArtist,
                                id: actionSheet.songId,
                                path: DownloadMgr.getDownloadPath(actionSheet.songId),
                                coverUrl: cover
                            }], 0);
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
                    color: addQueueMouse.pressed ? Theme.divider : "transparent"
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
                        id: addQueueMouse
                        anchors.fill: parent
                        onClicked: {
                            var cover = DownloadMgr.hasCover(actionSheet.songId) ? ("file://" + DownloadMgr.getCoverPath(actionSheet.songId)) : "";
                            mainView.currentPlaylistModel.append({
                                title: actionSheet.songTitle,
                                artist: actionSheet.songArtist,
                                id: actionSheet.songId,
                                path: DownloadMgr.getDownloadPath(actionSheet.songId),
                                coverUrl: cover
                            });
                            mainView.showToast(i18n.tr("Added to queue"), false, true);
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
                    color: deleteMouse.pressed ? Theme.divider : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: units.gu(1)
                        spacing: units.gu(2)
                        Icon {
                            name: "delete"
                            width: units.gu(2.4)
                            height: units.gu(2.4)
                            color: Theme.redCategory
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: i18n.tr("Delete from Device")
                            font.pixelSize: units.gu(2)
                            color: Theme.redCategory
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        onClicked: {
                            DownloadMgr.deleteDownloadedSong(actionSheet.songId);
                            Storage.removeDownloadedSongMetadata(actionSheet.songId);
                            loadSongs();
                            mainView.onDownloadsChanged();
                            actionSheet.close();
                        }
                    }
                }
            }
        }
    }

    function loadSongs() {
        listModel.clear();
        var list = DownloadMgr.getDownloadedSongsList();
        
        for (var i = 0; i < list.length; i++) {
            var songId = list[i].id;
            var storedAlbum = Storage.getSetting("dl_album_" + songId, i18n.tr("Downloaded Singles"));
            
            if (storedAlbum === albumName) {
                var storedTitle = Storage.getSetting("dl_title_" + songId, "");
                var storedArtist = Storage.getSetting("dl_artist_" + songId, "");
                
                listModel.append({
                    id: songId,
                    title: storedTitle || "Song " + songId,
                    artist: storedArtist || "Unknown",
                    path: list[i].path,
                    sizeText: DownloadMgr.formatSize(list[i].size),
                    coverPath: DownloadMgr.hasCover(songId) ? "file://" + DownloadMgr.getCoverPath(songId) : ""
                });
            }
        }
    }

    Component.onCompleted: loadSongs()
}
