import QtQuick 2.9
import Ubuntu.Components 1.3
import "../js/SynologyApi.js" as SynoApi
import "../js/Storage.js" as Storage

Page {
    id: settingsPage
    title: i18n.tr("Settings")

    head.actions: [
        Action {
            iconName: "back"
            text: i18n.tr("Back")
            onTriggered: pageStack.pop()
        }
    ]

    Flickable {
        id: pageFlick
        anchors.fill: parent
        contentHeight: contentCol.height + units.gu(4)
        clip: true

        Column {
            id: contentCol
            width: Math.min(parent.width - units.gu(4), units.gu(50))
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(2)
            topPadding: units.gu(2)

            Label {
                text: i18n.tr("Connected Account")
                font.weight: Font.Bold
                fontSize: "medium"
            }

            Rectangle {
                width: parent.width
                height: accountCol.height + units.gu(3)
                radius: units.gu(1)
                color: theme.palette.normal.base

                Column {
                    id: accountCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: units.gu(1.5)
                    }
                    spacing: units.gu(1)

                    Row {
                        spacing: units.gu(1)
                        Icon {
                            name: "contact"
                            width: units.gu(3)
                            height: units.gu(3)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: mainView.username || i18n.tr("Not logged in")
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        text: mainView.serverUrl || ""
                        fontSize: "small"
                        opacity: 0.7
                        elide: Text.ElideMiddle
                        width: parent.width
                    }
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Log Out")
                color: UbuntuColors.red
                onClicked: doLogout()
            }

            Rectangle {
                width: parent.width
                height: units.dp(1)
                color: UbuntuColors.slate
                opacity: 0.3
            }

            Label {
                text: i18n.tr("Application Information")
                font.weight: Font.Bold
                fontSize: "medium"
            }

            Button {
                width: parent.width
                text: i18n.tr("About & Disclaimer")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
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
            mainView.showToast(i18n.tr("Logged out successfully"), false, true);
            pageStack.clear();
            pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
        });
    }
}
