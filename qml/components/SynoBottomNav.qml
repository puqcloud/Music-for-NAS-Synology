import QtQuick 2.9
import Ubuntu.Components 1.3
import "../js/Theme.js" as Theme

Rectangle {
    id: root
    width: parent.width
    height: units.gu(7)
    color: Theme.background
    z: 100

    property int currentTab: 0 // 0: Library, 1: Downloaded, 2: Player, 3: More
    signal tabSelected(int index)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: units.dp(1)
        color: Theme.divider
    }

    Row {
        anchors.fill: parent
        
        property int activeTabsCount: 4
        property real tabWidth: parent.width / activeTabsCount

        // Tab 0: Library / Albums
        Item {
            width: parent.tabWidth
            visible: true
            height: parent.height

            Column {
                anchors.centerIn: parent
                spacing: units.dp(2)

                Icon {
                    name: mainView.isOfflineMode ? "media-optical" : "media-playlist"
                    width: units.gu(3)
                    height: units.gu(3)
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.currentTab === 0 ? Theme.primary : Theme.textMuted
                }

                Label {
                    text: mainView.isOfflineMode ? i18n.tr("Albums") : i18n.tr("Library")
                    fontSize: "x-small"
                    font.weight: root.currentTab === 0 ? Font.DemiBold : Font.Normal
                    color: root.currentTab === 0 ? Theme.primary : Theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentTab = 0;
                    root.tabSelected(0);
                }
            }
        }

        // Tab 1: Downloaded
        Item {
            width: parent.tabWidth
            height: parent.height

            Column {
                anchors.centerIn: parent
                spacing: units.dp(2)

                Icon {
                    name: "document-save"
                    width: units.gu(3)
                    height: units.gu(3)
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.currentTab === 1 ? Theme.primary : Theme.textMuted
                }

                Label {
                    text: i18n.tr("Downloaded")
                    fontSize: "x-small"
                    font.weight: root.currentTab === 1 ? Font.DemiBold : Font.Normal
                    color: root.currentTab === 1 ? Theme.primary : Theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentTab = 1;
                    root.tabSelected(1);
                }
            }
        }

        // Tab 2: Player
        Item {
            width: parent.tabWidth
            height: parent.height

            Column {
                anchors.centerIn: parent
                spacing: units.dp(2)

                Icon {
                    name: "media-playback-start"
                    width: units.gu(3)
                    height: units.gu(3)
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.currentTab === 2 ? Theme.primary : Theme.textMuted
                }

                Label {
                    text: i18n.tr("Player")
                    fontSize: "x-small"
                    font.weight: root.currentTab === 2 ? Font.DemiBold : Font.Normal
                    color: root.currentTab === 2 ? Theme.primary : Theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentTab = 2;
                    root.tabSelected(2);
                }
            }
        }

        // Tab 3: More
        Item {
            width: parent.tabWidth
            height: parent.height

            Column {
                anchors.centerIn: parent
                spacing: units.dp(2)

                Icon {
                    name: "navigation-menu"
                    width: units.gu(3)
                    height: units.gu(3)
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.currentTab === 3 ? (mainView.isOfflineMode ? Theme.redCategory : Theme.primary) : Theme.textMuted
                }

                Label {
                    text: i18n.tr("More")
                    fontSize: "x-small"
                    font.weight: root.currentTab === 3 ? Font.DemiBold : Font.Normal
                    color: root.currentTab === 3 ? Theme.primary : Theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.currentTab = 3;
                    root.tabSelected(3);
                }
            }
        }
    }
}
