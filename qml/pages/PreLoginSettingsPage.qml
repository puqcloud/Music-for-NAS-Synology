import QtQuick 2.9
import Ubuntu.Components 1.3
import "../components"
import "../js/Theme.js" as Theme
import "../js/Storage.js" as Storage
import "../js/DownloadManager.js" as DownloadMgr

Page {
    id: preLoginSettingsPage
    header: Item {
        width: preLoginSettingsPage.width
        height: 0
        visible: false
    }

    property int syncedCount: 0
    property string syncedSizeText: "0 MB"

    Component.onCompleted: refreshStats()

    Connections {
        target: mainView
        onCacheCleared: refreshStats()
    }

    function refreshStats() {
        var songList = DownloadMgr.getDownloadedSongsList();
        syncedCount = songList.length;
        var totalBytes = DownloadMgr.getTotalCacheSize();
        var mb = (totalBytes / (1024 * 1024)).toFixed(1);
        syncedSizeText = mb + " MB";
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Column {
        anchors.fill: parent

        SynoHeader {
            title: i18n.tr("Settings")
            showBack: true
            onBackClicked: pageStack.pop()
        }

        Flickable {
            id: pageFlick
            width: parent.width
            height: parent.height - units.gu(6)
            contentHeight: contentCol.height + units.gu(4)
            clip: true

            Column {
                id: contentCol
                width: parent.width
                spacing: 0

                // Clear Cache
                Item {
                    width: parent.width
                    height: units.gu(8)

                    Rectangle {
                        anchors.fill: parent
                        color: clearCacheMouse.pressed ? "#F5F5F7" : "transparent"

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: units.gu(2.5)
                            }
                            spacing: units.gu(2)

                            Icon {
                                name: "delete"
                                width: units.gu(2.8)
                                height: units.gu(2.8)
                                color: Theme.textDark
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - units.gu(6)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: units.dp(2)

                                Label {
                                    text: i18n.tr("Clear Cache")
                                    font.pixelSize: units.gu(1.9)
                                    font.weight: Font.DemiBold
                                    color: Theme.textDark
                                }

                                Label {
                                    text: i18n.tr("Safely delete %1 downloaded songs (%2)").arg(preLoginSettingsPage.syncedCount).arg(preLoginSettingsPage.syncedSizeText)
                                    font.pixelSize: units.gu(1.4)
                                    color: Theme.textMuted
                                }
                            }
                        }

                        MouseArea {
                            id: clearCacheMouse
                            anchors.fill: parent
                            onClicked: {
                                DownloadMgr.clearAllDownloads();
                                Storage.clearAllDownloadsMetadata();
                                preLoginSettingsPage.refreshStats();
                                mainView.onDownloadsChanged();
                                mainView.showToast(i18n.tr("Cache cleared successfully"), false, true);
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: units.dp(1)
                        color: Theme.divider
                    }
                }

                // Reset App
                Item {
                    width: parent.width
                    height: units.gu(8)

                    Rectangle {
                        anchors.fill: parent
                        color: resetAppMouse.pressed ? "#F5F5F7" : "transparent"

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: units.gu(2.5)
                            }
                            spacing: units.gu(2)

                            Icon {
                                name: "edit-clear"
                                width: units.gu(2.8)
                                height: units.gu(2.8)
                                color: "#FF3B30"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - units.gu(6)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: units.dp(2)

                                Label {
                                    text: i18n.tr("Reset App")
                                    font.pixelSize: units.gu(1.9)
                                    font.weight: Font.DemiBold
                                    color: "#FF3B30"
                                }

                                Label {
                                    text: i18n.tr("Erase all data and restore the app to its fresh-install state")
                                    font.pixelSize: units.gu(1.4)
                                    color: Theme.textMuted
                                }
                            }
                        }

                        MouseArea {
                            id: resetAppMouse
                            anchors.fill: parent
                            onClicked: {
                                mainView.showErrorDialog(i18n.tr("Reset App"),
                                    i18n.tr("This will erase all app data: your login, downloaded songs, playlists, and settings. The app will be restored to its fresh-install state. This cannot be undone."),
                                    i18n.tr("Reset"), i18n.tr("Cancel"),
                                    function() {
                                        mainView.clearPlayerQueue();
                                        DownloadMgr.clearAllDownloads();
                                        Storage.fullReset();
                                        mainView.isLoggedIn = false;
                                        mainView.isOfflineMode = false;
                                        mainView.sid = "";
                                        mainView.synotoken = "";
                                        mainView.username = "";
                                        mainView.serverUrl = "";
                                        mainView.cacheCleared();
                                        pageStack.clear();
                                        pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
                                    },
                                    function() {});
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: units.dp(1)
                        color: Theme.divider
                    }
                }
            }
        }

        Scrollbar {
            flickableItem: pageFlick
            align: Qt.AlignTrailing
        }
    }
}
