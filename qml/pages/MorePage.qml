import QtQuick 2.9
import Ubuntu.Components 1.3
import "../components"
import "../js/Theme.js" as Theme
import "../js/SynologyApi.js" as SynoApi
import "../js/Storage.js" as Storage
import "../js/DownloadManager.js" as DownloadMgr

Item {
    id: moreTab
    anchors.fill: parent

    property int syncedCount: 0
    property string syncedSizeText: "0 MB"
    property string cacheSizeText: "0 MB"

    Component.onCompleted: {
        refreshStats();
    }
    
    Connections {
        target: mainView
        onDownloadFinished: refreshStats()
        onCacheCleared: refreshStats()
    }

    function refreshStats() {
        var songList = DownloadMgr.getDownloadedSongsList();
        syncedCount = songList.length;
        var totalBytes = DownloadMgr.getTotalCacheSize();
        var mb = (totalBytes / (1024 * 1024)).toFixed(1);
        syncedSizeText = mb + " MB";
        cacheSizeText = mb + " MB";
    }

    Flickable {
        id: pageFlick
        anchors.fill: parent
        contentHeight: contentCol.height + units.gu(4)
        clip: true

        Column {
            id: contentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            spacing: 0

            // 1. User Profile Header
            Item {
                width: parent.width
                height: units.gu(11)

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: units.gu(2.5)
                    }
                    spacing: units.gu(2)

                    Column {
                        width: parent.width - units.gu(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.4)

                        Label {
                            text: mainView.username || "User"
                            font.pixelSize: units.gu(2.6)
                            font.weight: Font.Bold
                            color: Theme.textDark
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Label {
                            text: mainView.serverUrl || ""
                            font.pixelSize: units.gu(1.6)
                            color: Theme.textMuted
                            elide: Text.ElideMiddle
                            width: parent.width
                        }
                    }

                    Rectangle {
                        width: units.gu(6.5)
                        height: units.gu(6.5)
                        radius: units.gu(3.25)
                        color: "#EAECEF"
                        anchors.verticalCenter: parent.verticalCenter

                        Icon {
                            anchors.centerIn: parent
                            name: "contact"
                            width: units.gu(4)
                            height: units.gu(4)
                            color: "#B0B5BD"
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

            // 1.5. Offline / Online Mode Toggle
            Item {
                width: parent.width
                height: units.gu(8)
                
                Rectangle {
                    anchors.fill: parent
                    color: toggleModeMouse.pressed ? "#F5F5F7" : "transparent"

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: units.gu(2.5)
                        }
                        spacing: units.gu(2)

                        Icon {
                            name: mainView.isOfflineMode ? "network-wireless" : "network-offline"
                            width: units.gu(2.8)
                            height: units.gu(2.8)
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - units.gu(6)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: units.dp(2)

                            Label {
                                text: mainView.isOfflineMode ? i18n.tr("Go Online") : i18n.tr("Go Offline")
                                font.pixelSize: units.gu(1.9)
                                font.weight: Font.DemiBold
                                color: Theme.textDark
                            }

                            Label {
                                text: mainView.isOfflineMode ? i18n.tr("Connect to Synology NAS") : i18n.tr("Use downloaded music only")
                                font.pixelSize: units.gu(1.4)
                                color: Theme.textMuted
                            }
                        }
                    }

                    MouseArea {
                        id: toggleModeMouse
                        anchors.fill: parent
                        onClicked: {
                            if (mainView.isOfflineMode) {
                                if (Storage.getSetting("sid", "")) {
                                    mainView.isOfflineMode = false;
                                    mainView.showToast(i18n.tr("Switched to Online Mode"), false, true);
                                    if (typeof bottomNav !== 'undefined') {
                                        bottomNav.currentTab = 0;
                                    }
                                } else {
                                    mainView.isOfflineMode = false;
                                    mainView.isLoggedIn = false;
                                    pageStack.clear();
                                    pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
                                }
                            } else {
                                mainView.isOfflineMode = true;
                                mainView.showToast(i18n.tr("Switched to Offline Mode"), false, true);
                            }
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

            // 3. Settings
            Item {
                width: parent.width
                height: units.gu(7.5)

                Rectangle {
                    anchors.fill: parent
                    color: settingsMouse.pressed ? "#F5F5F7" : "transparent"

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: units.gu(2.5)
                        }
                        spacing: units.gu(2)

                        Icon {
                            name: "settings"
                            width: units.gu(2.8)
                            height: units.gu(2.8)
                            color: Theme.textDark
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: i18n.tr("Settings")
                            font.pixelSize: units.gu(2)
                            color: Theme.textDark
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(8)
                        }

                        Icon {
                            name: "next"
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            color: Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        onClicked: pageStack.push(Qt.resolvedUrl("PreLoginSettingsPage.qml"));
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: units.dp(1)
                    color: Theme.divider
                }
            }

            // 4. About & Disclaimer
            Item {
                width: parent.width
                height: units.gu(7.5)

                Rectangle {
                    anchors.fill: parent
                    color: aboutMouse.pressed ? "#F5F5F7" : "transparent"

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: units.gu(2.5)
                        }
                        spacing: units.gu(2)

                        Icon {
                            name: "dialog-information"
                            width: units.gu(2.8)
                            height: units.gu(2.8)
                            color: Theme.textDark
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: i18n.tr("About & Disclaimer")
                            font.pixelSize: units.gu(2)
                            color: Theme.textDark
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(8)
                        }

                        Icon {
                            name: "next"
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            color: Theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: aboutMouse
                        anchors.fill: parent
                        onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"));
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: units.dp(1)
                    color: Theme.divider
                }
            }

            // 5. Log Out
            Item {
                width: parent.width
                height: units.gu(7.5)

                Rectangle {
                    anchors.fill: parent
                    color: logoutMouse.pressed ? "#F5F5F7" : "transparent"

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: units.gu(2.5)
                        }
                        spacing: units.gu(2)

                        Icon {
                            name: "system-log-out"
                            width: units.gu(2.8)
                            height: units.gu(2.8)
                            color: Theme.textDark
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: i18n.tr("Log Out")
                            font.pixelSize: units.gu(2)
                            color: Theme.textDark
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: logoutMouse
                        anchors.fill: parent
                        onClicked: doLogout()
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

    function doLogout() {
        mainView.showLoading(i18n.tr("Logging out..."));
        SynoApi.logout(mainView.serverUrl, mainView.sid, mainView.synotoken, function() {
            mainView.hideLoading();
            Storage.clearAllCredentials();
            Storage.clearLibraryCache();
            SynoApi.clearFolderCache();
            mainView.sid = "";
            mainView.synotoken = "";
            mainView.isLoggedIn = false;
            mainView.isOfflineMode = false;
            pageStack.clear();
            pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
        });
    }
}
