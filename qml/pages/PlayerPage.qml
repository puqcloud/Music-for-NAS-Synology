import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import QtMultimedia 5.8
import "../components"
import "../js/Theme.js" as Theme
import "../js/DownloadManager.js" as DownloadMgr

Page {
    id: playerPage
    property bool isPlaylistView: false

    // Re-scroll the queue when the user opens the playlist view.
    onIsPlaylistViewChanged: {
        if (isPlaylistView) scrollTimer.restart();
    }

    function formatTime(ms) {
        if (isNaN(ms) || ms <= 0) return "0:00";
        var s = Math.floor(ms / 1000);
        var m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    header: Item { width: parent.width; height: 0; visible: false }

    SynoHeader {
        id: pageHeader
        title: "Player"
        showBack: true
        showCustomIcon: true
        customIconName: isPlaylistView ? "media-playback-start" : "view-list-symbolic"
        showClear: isPlaylistView
        onBackClicked: { 
            if (mainView.isOfflineMode) {
                bottomNav.currentTab = 1; 
                bottomNav.tabSelected(1);
            } else {
                bottomNav.currentTab = 0; 
                bottomNav.tabSelected(0);
            }
        }
        onCustomClicked: { isPlaylistView = !isPlaylistView; }
        onClearClicked: {
            mainView.clearPlayerQueue();
            isPlaylistView = false;
        }
    }

    Rectangle {
        anchors.top: pageHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#2C2C2C"

        // ---------------------------------------------------------
        // PLAYLIST VIEW
        // ---------------------------------------------------------
        ListView {
            id: playlistView
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: bottomControlsArea.top
            visible: isPlaylistView
            clip: true

            model: mainView.currentPlaylistModel
            delegate: Item {
                width: playlistView.width
                height: units.gu(8)

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: units.dp(1)
                    color: "#444444"
                }

                Rectangle {
                    anchors.fill: parent
                    color: index === mainView.currentTrackIndex ? "#1A1A1A" : "transparent"

                    Rectangle {
                        id: coverRect
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(6)
                        height: units.gu(6)
                        color: "transparent"

                        Icon {
                            name: index === mainView.currentTrackIndex ? "media-playback-start" : "audio-x-generic"
                            anchors.centerIn: parent
                            color: index === mainView.currentTrackIndex ? Theme.primary : Theme.primaryLight
                            width: units.gu(4)
                            height: units.gu(4)
                        }
                    }

                    Column {
                        anchors.left: coverRect.right
                        anchors.leftMargin: units.gu(1.5)
                        anchors.right: menuIconItem.left
                        anchors.rightMargin: units.gu(1.5)
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            text: title || ""
                            font.weight: Font.Bold
                            font.pixelSize: units.gu(2.2)
                            color: "white"
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Label {
                            text: artist || ""
                            font.pixelSize: units.gu(1.6)
                            color: "#AAAAAA"
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
                            color: menuArea.pressed ? "#555555" : "transparent"

                            Icon {
                                name: "navigation-menu"
                                width: units.gu(2.8)
                                height: units.gu(2.8)
                                color: "#AAAAAA"
                                anchors.centerIn: parent
                            }
                        }

                        MouseArea {
                            id: menuArea
                            anchors.fill: parent
                            z: 10
                            onClicked: {
                                PopupUtils.open(playlistActionPopover, playerPage, { trackIndex: index });
                            }
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: menuIconItem.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        onClicked: {
                            // Pass the model directly: copying to a plain array would
                            // make playTrack() rebuild the model and destroy this very
                            // delegate while its signal handler is still running.
                            mainView.playTrack(mainView.currentPlaylistModel, index);
                        }
                    }
                }
            }
        }

        Scrollbar {
            flickableItem: playlistView
            align: Qt.AlignTrailing
        }

        // Keep the currently playing track visible at the top of the queue,
        // both on manual switch and on automatic advance to the next song.
        Connections {
            target: mainView
            onCurrentTrackIndexChanged: scrollTimer.restart()
        }

        Component.onCompleted: scrollTimer.restart()

        // The model may be rebuilt at the same moment the index changes, so
        // position the view slightly later to let delegate items be created.
        Timer {
            id: scrollTimer
            interval: 100
            repeat: false
            onTriggered: {
                var idx = mainView.currentTrackIndex;
                if (idx >= 0 && idx < playlistView.count) {
                    playlistView.positionViewAtIndex(idx, ListView.Beginning);
                }
            }
        }

        Component {
            id: playlistActionPopover
            Popover {
                id: popover
                property int trackIndex: -1

                Column {
                    width: units.gu(25)

                    Rectangle {
                        width: parent.width
                        height: units.gu(6)
                        color: removeMouse.pressed ? Theme.divider : "transparent"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: units.gu(2)
                            spacing: units.gu(2)
                            Icon {
                                name: "delete"
                                width: units.gu(2.4)
                                height: units.gu(2.4)
                                color: Theme.textDark
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: i18n.tr("Remove from Queue")
                                font.pixelSize: units.gu(2)
                                color: Theme.textDark
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            onClicked: {
                                if (popover.trackIndex >= 0 && popover.trackIndex < mainView.currentPlaylistModel.count) {
                                    if (popover.trackIndex === mainView.currentTrackIndex) {
                                        mainView.clearPlayerQueue();
                                    } else {
                                        if (popover.trackIndex < mainView.currentTrackIndex) {
                                            mainView.currentTrackIndex -= 1;
                                        }
                                        mainView.currentPlaylistModel.remove(popover.trackIndex);
                                        mainView.resyncPlayerPlaylist();
                                        mainView.savePlaylist();
                                    }
                                }
                                PopupUtils.close(popover);
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // COVER VIEW
        // ---------------------------------------------------------
        Item {
            id: coverView
            anchors.top: parent.top
            anchors.bottom: bottomControlsArea.top
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !isPlaylistView

            // Text Info at top
            Column {
                anchors.top: parent.top
                anchors.topMargin: units.gu(3)
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - units.gu(6)

                Label {
                    text: mainView.currentTrack ? (mainView.currentTrack.title || "") : i18n.tr("No Track Selected")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.weight: Font.Bold
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    elide: Text.ElideRight
                }

                Item { width: 1; height: units.gu(0.4) }

                Label {
                    text: mainView.currentTrack ? (mainView.currentTrack.artist || "") : ""
                    color: "#AAAAAA"
                    font.pixelSize: units.gu(1.7)
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    elide: Text.ElideRight
                }
            }

            // Cover art behind the ring
            Rectangle {
                id: coverArt
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.85, units.gu(38)) * 0.55
                height: width
                radius: units.gu(1)
                color: "#1A1A1A"

                Icon {
                    name: "media-optical"
                    anchors.centerIn: parent
                    width: units.gu(8)
                    height: units.gu(8)
                    color: "#444444"
                    visible: coverImage.status !== Image.Ready
                }

                Image {
                    id: coverImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: mainView.currentTrack ? (mainView.currentTrack.coverUrl || "") : ""
                }
            }

            // Circular seek ring on top of cover
            CircularSeek {
                id: circularSeek
                anchors.centerIn: parent
                progress: mainView.trackGeneration >= 0 && globalPlayer.duration > 0 ? globalPlayer.position / globalPlayer.duration : 0
                duration: globalPlayer.duration
                position: globalPlayer.position
                isPlaying: globalPlayer.playbackState === Audio.PlayingState
                cached: mainView.currentTrack && mainView.currentTrack.id ? DownloadMgr.isDownloaded(mainView.currentTrack.id) : false
                downloadProgress: mainView.downloadProgress
                resetKey: mainView.trackGeneration
                onSeekRequested: {
                    if (globalPlayer.duration > 0) globalPlayer.seek(newPos);
                }
            }
        }

        // ---------------------------------------------------------
        // BOTTOM CONTROLS
        // ---------------------------------------------------------
        Rectangle {
            id: bottomControlsArea
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(10)
            color: "#2C2C2C"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: units.dp(1)
                color: "#444444"
            }

            Row {
                anchors.centerIn: parent
                spacing: units.gu(3)

                Icon { 
                    name: "media-playlist-shuffle"
                    width: units.gu(3)
                    height: units.gu(3)
                    color: mainView.shuffleMode ? Theme.primary : "#888888"
                    MouseArea { anchors.fill: parent; onClicked: mainView.shuffleMode = !mainView.shuffleMode }
                }

                Icon { 
                    name: "media-skip-backward"
                    width: units.gu(4)
                    height: units.gu(4)
                    color: "#888888"
                    MouseArea { anchors.fill: parent; onClicked: mainView.prevTrack() }
                }

                Icon {
                    name: globalPlayer.playbackState === Audio.PlayingState ? "media-playback-pause" : "media-playback-start"
                    width: units.gu(5.5)
                    height: units.gu(5.5)
                    color: Theme.primary
                    MouseArea { anchors.fill: parent; onClicked: mainView.togglePlayPause() }
                }

                Icon { 
                    name: "media-skip-forward"
                    width: units.gu(4)
                    height: units.gu(4)
                    color: "#888888"
                    MouseArea { anchors.fill: parent; onClicked: mainView.nextTrack() }
                }

                Item {
                    width: units.gu(3)
                    height: units.gu(3)
                    
                    Icon { 
                        anchors.fill: parent
                        name: "media-playlist-repeat"
                        color: mainView.repeatMode > 0 ? Theme.primary : "#888888"
                    }
                    
                    Rectangle {
                        width: units.gu(1.6)
                        height: units.gu(1.6)
                        radius: units.gu(0.8)
                        color: Theme.background
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: -units.gu(0.4)
                        visible: mainView.repeatMode === 2
                        
                        Label {
                            text: "1"
                            color: Theme.primary
                            font.pixelSize: units.gu(1.2)
                            font.weight: Font.Bold
                            anchors.centerIn: parent
                        }
                    }
                    
                    MouseArea { 
                        anchors.fill: parent
                        onClicked: { mainView.repeatMode = (mainView.repeatMode + 1) % 3; }
                    }
                }
            }
        }
    }
}
