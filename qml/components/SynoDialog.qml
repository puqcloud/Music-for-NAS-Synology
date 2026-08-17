import QtQuick 2.9
import Ubuntu.Components 1.3
import "../js/Theme.js" as Theme

Rectangle {
    id: root
    anchors.fill: parent
    color: "#75000000"
    visible: opacity > 0
    opacity: 0
    z: 9999

    property string title: ""
    property string message: ""
    property string buttonText: i18n.tr("OK")
    property string cancelText: ""
    property bool showCancel: false
    property var okCallback: null
    property var cancelCallback: null

    signal accepted()
    signal rejected()

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    // Tap backdrop to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.close();
            if (root.cancelCallback) root.cancelCallback();
            root.rejected();
        }
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - units.gu(6), units.gu(36))
        height: dialogColumn.height
        anchors.centerIn: parent
        radius: units.gu(1.8)
        color: "#ffffff"

        // Prevent click leaking through card to backdrop
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onClicked: {}
        }

        Column {
            id: dialogColumn
            width: parent.width

            // Text Content Box with white background so highlight behind it doesn't bleed through
            Rectangle {
                id: textContainer
                width: parent.width
                height: textCol.height + units.gu(5)
                color: "#ffffff"
                radius: card.radius
                z: 2

                Column {
                    id: textCol
                    anchors.centerIn: parent
                    width: parent.width - units.gu(5)
                    spacing: units.gu(1.2)

                    Label {
                        text: root.title
                        font.pixelSize: units.gu(2.2)
                        font.weight: Font.Bold
                        color: Theme.textDark
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.title.length > 0
                        wrapMode: Text.Wrap
                        width: parent.width
                    }

                    Label {
                        text: root.message
                        font.pixelSize: units.gu(1.65)
                        color: "#4A4A4A"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.Wrap
                        width: parent.width
                        lineHeight: 1.25
                        textFormat: Text.RichText
                        onLinkActivated: Qt.openUrlExternally(link)
                    }
                }
            }

            // Bottom Action Area (Full width, attached to bottom)
            Item {
                id: actionArea
                width: parent.width
                height: units.gu(5.5)
                z: 1

                // Top divider line
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: units.dp(1)
                    color: "#E5E5EA"
                    z: 5
                }

                // Case 1: Single OK button (full width)
                Item {
                    anchors.fill: parent
                    visible: !root.showCancel

                    // Pressed highlight with matching bottom rounded corners
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            top: parent.top
                            topMargin: -card.radius
                        }
                        radius: card.radius
                        color: singleOkMouse.pressed ? "#F0F0F2" : "transparent"
                        z: 1
                    }

                    Label {
                        anchors.centerIn: parent
                        text: root.buttonText
                        font.pixelSize: units.gu(2.0)
                        font.weight: Font.DemiBold
                        color: Theme.primary
                        z: 2
                    }

                    MouseArea {
                        id: singleOkMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        z: 3
                        onClicked: {
                            root.close();
                            if (root.okCallback) root.okCallback();
                            root.accepted();
                        }
                    }
                }

                // Case 2: Two buttons (Cancel | OK)
                Row {
                    anchors.fill: parent
                    visible: root.showCancel

                    // Left: Cancel
                    Item {
                        width: (parent.width - units.dp(1)) / 2
                        height: parent.height

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                rightMargin: -card.radius
                                bottom: parent.bottom
                                top: parent.top
                                topMargin: -card.radius
                            }
                            radius: card.radius
                            color: cancelMouse.pressed ? "#F0F0F2" : "transparent"
                            z: 1
                        }

                        Label {
                            anchors.centerIn: parent
                            text: root.cancelText || i18n.tr("Cancel")
                            font.pixelSize: units.gu(1.9)
                            font.weight: Font.Normal
                            color: "#007AFF"
                            z: 2
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            z: 3
                            onClicked: {
                                root.close();
                                if (root.cancelCallback) root.cancelCallback();
                                root.rejected();
                            }
                        }
                    }

                    // Vertical Divider
                    Rectangle {
                        width: units.dp(1)
                        height: parent.height
                        color: "#E5E5EA"
                        z: 5
                    }

                    // Right: OK / Confirm
                    Item {
                        width: (parent.width - units.dp(1)) / 2
                        height: parent.height

                        Rectangle {
                            anchors {
                                left: parent.left
                                leftMargin: -card.radius
                                right: parent.right
                                bottom: parent.bottom
                                top: parent.top
                                topMargin: -card.radius
                            }
                            radius: card.radius
                            color: okMouse.pressed ? "#F0F0F2" : "transparent"
                            z: 1
                        }

                        Label {
                            anchors.centerIn: parent
                            text: root.buttonText
                            font.pixelSize: units.gu(1.9)
                            font.weight: Font.DemiBold
                            color: Theme.primary
                            z: 2
                        }

                        MouseArea {
                            id: okMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            z: 3
                            onClicked: {
                                root.close();
                                if (root.okCallback) root.okCallback();
                                root.accepted();
                            }
                        }
                    }
                }
            }
        }
    }

    function escapeHtml(s) {
        var str = s === undefined || s === null ? "" : String(s);
        str = str.replace(/&/g, "&amp;");
        str = str.replace(/</g, "&lt;");
        str = str.replace(/>/g, "&gt;");
        str = str.replace(/"/g, "&quot;");
        str = str.replace(/'/g, "&#39;");
        return str;
    }

    function show(dialogTitle, dialogMsg, btnText, cText, onOk, onCancel) {
        root.title = escapeHtml(dialogTitle || "");
        // Escape dynamic content to prevent HTML injection from server
        // derived strings (e.g. track titles); plain newlines become <br>.
        root.message = escapeHtml(dialogMsg || "").replace(/\n/g, "<br>");
        root.buttonText = btnText || i18n.tr("OK");
        root.cancelText = cText || "";
        root.showCancel = !!cText;
        root.okCallback = onOk || null;
        root.cancelCallback = onCancel || null;
        root.opacity = 1.0;
    }

    function close() {
        root.opacity = 0;
    }
}
