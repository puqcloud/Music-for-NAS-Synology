import QtQuick 2.9
import Ubuntu.Components 1.3
import "../components"
import "../js/Theme.js" as Theme

Page {
    id: mainTabsPage
    header: Item {
        width: mainTabsPage.width
        height: 0
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Item {
        id: tabContent
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: bottomNav.top
            bottomMargin: miniPlayerItem.visible ? miniPlayerItem.height : 0
        }

        Loader {
            id: tab0Loader
            anchors.fill: parent
            source: mainView.isOfflineMode ? "OfflineAlbumsTab.qml" : "LibraryTab.qml"
            visible: bottomNav.currentTab === 0
        }

        Loader {
            id: tab1Loader
            anchors.fill: parent
            source: "DownloadedPage.qml"
            visible: bottomNav.currentTab === 1
        }

        Loader {
            id: tab2Loader
            anchors.fill: parent
            source: "PlayerPage.qml"
            visible: bottomNav.currentTab === 2
        }

        Loader {
            id: tab3Loader
            anchors.fill: parent
            source: "MorePage.qml"
            visible: bottomNav.currentTab === 3
        }
    }

    MiniPlayer {
        id: miniPlayerItem
        anchors {
            left: parent.left
            right: parent.right
            bottom: bottomNav.top
        }
        visible: bottomNav.currentTab !== 2 && mainView.currentTrackIndex >= 0
    }

    SynoBottomNav {
        id: bottomNav
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        currentTab: mainView.isOfflineMode ? 1 : 0
        Component.onCompleted: {
            if (mainView.isOfflineMode) currentTab = 1;
        }
        onTabSelected: {
            // Future tab selected logic
        }
    }
}
