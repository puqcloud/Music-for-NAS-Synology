import QtQuick 2.9
import Ubuntu.Components 1.3
import QtMultimedia 5.8
import "../js/Theme.js" as Theme

Rectangle {
    id: miniPlayer
    height: units.gu(7)
    color: "#2C2C2C"
    
    property string title: mainView.currentTrack ? mainView.currentTrack.title : i18n.tr("Not playing")
    property string artist: mainView.currentTrack ? mainView.currentTrack.artist : ""
    property bool isPlaying: globalPlayer.playbackState === Audio.PlayingState

    Rectangle {
        id: progressBar
        height: units.dp(2)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        color: Theme.primary
        transform: Scale {
            origin.x: 0
            xScale: globalPlayer.duration > 0 && globalPlayer.position > 0
                    ? Math.min(1, globalPlayer.position / globalPlayer.duration) : 0
        }
    }

    Rectangle {
        height: units.dp(2)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        color: "#33FFE0"
        opacity: mainView.downloadProgress > 0 ? 0.7 : 0
        transform: Scale {
            origin.x: 0
            xScale: mainView.downloadProgress > 0
                    ? Math.min(1, mainView.downloadProgress) : 0
        }
    }
    
    Row {
        anchors.fill: parent
        anchors.margins: units.gu(1)
        spacing: units.gu(1.5)
        
        Rectangle {
            width: units.gu(5)
            height: units.gu(5)
            color: "#444444"
            anchors.verticalCenter: parent.verticalCenter
            
            Icon {
                name: "media-optical"
                anchors.centerIn: parent
                color: "#888888"
                width: units.gu(3)
                height: units.gu(3)
                visible: miniCoverImage.status !== Image.Ready
            }
            
            Image {
                id: miniCoverImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: mainView.currentTrack ? (mainView.currentTrack.coverUrl || "") : ""
            }
        }
        
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - units.gu(18)
            Label {
                text: miniPlayer.title
                color: "#FFFFFF"
                font.weight: Font.Bold
                font.pixelSize: units.gu(1.8)
                elide: Text.ElideRight
                width: parent.width
            }
            Label {
                text: miniPlayer.artist
                color: "#AAAAAA"
                font.pixelSize: units.gu(1.5)
                elide: Text.ElideRight
                width: parent.width
            }
        }
        
        Icon {
            name: miniPlayer.isPlaying ? "media-playback-pause" : "media-playback-start"
            color: Theme.primary
            width: units.gu(4)
            height: units.gu(4)
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                onClicked: mainView.togglePlayPause()
            }
        }
        
        Icon {
            name: "media-skip-forward"
            color: "#AAAAAA"
            width: units.gu(3)
            height: units.gu(3)
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                onClicked: mainView.nextTrack()
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            bottomNav.currentTab = 2;
            bottomNav.tabSelected(2);
        }
    }
}
