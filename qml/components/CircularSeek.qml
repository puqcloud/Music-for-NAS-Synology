import QtQuick 2.9
import Ubuntu.Components 1.3
import "../js/Theme.js" as Theme

Item {
    id: root
    width: Math.min(parent.width * 0.85, units.gu(38))
    height: width

    property real progress: 0.0  // 0.0 to 1.0 — set by PlayerPage binding
    property real duration: 0
    property real position: 0
    property bool isPlaying: false
    property color trackColor: "#444444"
    property color progressColor: Theme.primary
    property color cachedColor: "#33FFE0"
    property bool cached: false
    property real downloadProgress: -1 // -1 = hide, 0..1 = downloading
    property int resetKey: 0 // incremented to force redraw on track change
    property real arcWidth: units.dp(4)

    // Internal: track resetting state and drag state
    property bool _isResetting: false
    property real _dragProgress: 0
    property bool _isSeeking: false

    Timer {
        id: seekDelayTimer
        interval: 2000
        onTriggered: {
            root._isSeeking = false
            canvas.requestPaint()
        }
    }

    Timer {
        id: resetSafetyTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root._isResetting) {
                root._isResetting = false
                canvas.requestPaint()
            }
        }
    }

    // Instantly repaint and clear resetting flags when returning from background
    Connections {
        target: Qt.application
        onActiveChanged: {
            if (Qt.application.active) {
                root._isResetting = false
                if (!seekArea.dragging) root._isSeeking = false
                canvas.requestPaint()
            }
        }
        onStateChanged: {
            if (Qt.application.state === Qt.ApplicationActive) {
                root._isResetting = false
                if (!seekArea.dragging) root._isSeeking = false
                canvas.requestPaint()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            root._isResetting = false
            if (!seekArea.dragging) root._isSeeking = false
            canvas.requestPaint()
        }
    }

    signal seekRequested(real newPos)

    function formatTime(ms) {
        if (isNaN(ms) || ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    // While a new track is loading media-hub can report a garbage (huge)
    // duration, so clamp the displayed times until the real duration arrives.
    function displayPositionMs() {
        var d = root.duration
        var p = (seekArea.dragging || root._isSeeking) ? (root._dragProgress * root.duration) : root.position
        if (isNaN(p) || p < 0) p = 0
        if (!isNaN(d) && d > 0 && p > d) p = d
        return p
    }

    function remainingTimeMs() {
        var d = root.duration
        // media-hub reports a garbage (huge) duration while a new track loads;
        // 12 hours is a generous sanity cap for a song.
        if (isNaN(d) || d <= 0 || d > 43200000) return 0
        var p = displayPositionMs()
        if (p > d) return 0
        return d - p
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: units.gu(3)

        property real cx: width / 2
        property real cy: height / 2
        property real r: Math.min(cx, cy) - root.arcWidth / 2 - units.dp(8)

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var startAngle = Math.PI * 1.5 // top (12 o'clock)
            var fullArc = Math.PI * 2

            // Background track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, fullArc)
            ctx.strokeStyle = root.trackColor
            ctx.lineWidth = root.arcWidth
            ctx.lineCap = "round"
            ctx.stroke()

            // Cached indicator ring (pale teal, outer)
            if (root.cached) {
                ctx.beginPath()
                ctx.arc(cx, cy, r + units.dp(4), 0, fullArc)
                ctx.strokeStyle = root.cachedColor
                ctx.lineWidth = units.dp(2)
                ctx.lineCap = "round"
                ctx.stroke()
            }

            // Effective progress: 0 if resetting, or _dragProgress if dragging/seeking
            var effProgress = (seekArea.dragging || root._isSeeking) ? root._dragProgress : (root._isResetting ? 0 : root.progress);

            // Download progress arc (inner ring)
            if (!root._isResetting && root.downloadProgress > 0.001) {
                ctx.beginPath()
                var dlSweep = fullArc * root.downloadProgress
                ctx.arc(cx, cy, r - units.dp(5), startAngle, startAngle + dlSweep, false)
                ctx.strokeStyle = "#33FFE0"
                ctx.lineWidth = units.dp(3)
                ctx.lineCap = "round"
                ctx.stroke()
            }

            // Progress arc
            if (effProgress > 0.001) {
                ctx.beginPath()
                var sweepAngle = fullArc * effProgress
                ctx.arc(cx, cy, r, startAngle, startAngle + sweepAngle, false)
                ctx.strokeStyle = root.progressColor
                ctx.lineWidth = root.arcWidth
                ctx.lineCap = "round"
                ctx.stroke()
            }

            // Thumb dot
            if (effProgress > 0) {
                var dotAngle = startAngle + fullArc * effProgress
                var dotX = cx + r * Math.cos(dotAngle)
                var dotY = cy + r * Math.sin(dotAngle)

                ctx.beginPath()
                ctx.arc(dotX, dotY, units.dp(8), 0, fullArc)
                ctx.fillStyle = root.progressColor
                ctx.fill()

                ctx.beginPath()
                ctx.arc(dotX, dotY, units.dp(5), 0, fullArc)
                ctx.fillStyle = "#FFFFFF"
                ctx.fill()
            }
        }

        onAvailableChanged: {
            if (available) {
                canvas.requestPaint();
            }
        }

        Connections {
            target: root
            onProgressChanged: {
                if (root._isResetting && root.progress < 0.05) {
                    root._isResetting = false;
                    resetSafetyTimer.stop();
                }
                if (root._isSeeking && Math.abs(root.progress - root._dragProgress) < 0.02) {
                    root._isSeeking = false;
                    seekDelayTimer.stop();
                }
                canvas.requestPaint();
            }
            onDurationChanged: canvas.requestPaint()
            onPositionChanged: canvas.requestPaint()
            onDownloadProgressChanged: canvas.requestPaint()
            onCachedChanged: canvas.requestPaint()
            onWidthChanged: canvas.requestPaint()
        }

        MouseArea {
            id: seekArea
            anchors.fill: parent

            property bool dragging: false

            function angleFromPoint(px, py) {
                var dx = px - canvas.cx
                var dy = py - canvas.cy
                var a = Math.atan2(dy, dx)
                // Normalize to top (12 o'clock) as 0
                a -= Math.PI * 1.5
                while (a < 0) a += Math.PI * 2
                return a
            }

            function progressFromPoint(px, py) {
                var a = angleFromPoint(px, py)
                return a / (Math.PI * 2)
            }

            onPressed: {
                dragging = true
                root._isResetting = false
                resetSafetyTimer.stop()
                var p = progressFromPoint(mouse.x, mouse.y)
                root._dragProgress = Math.max(0, Math.min(1, p))
                canvas.requestPaint()
            }

            onPositionChanged: {
                if (dragging) {
                    var p = progressFromPoint(mouse.x, mouse.y)
                    root._dragProgress = Math.max(0, Math.min(1, p))
                    canvas.requestPaint()
                }
            }

            onReleased: {
                if (dragging) {
                    dragging = false
                    root._isSeeking = true
                    seekDelayTimer.restart()
                    var newMs = root._dragProgress * root.duration
                    root.seekRequested(newMs)
                    canvas.requestPaint()
                }
            }
        }
    }

    onResetKeyChanged: {
        _isResetting = true;
        resetSafetyTimer.restart();
        canvas.requestPaint()
    }

    // Time labels
    Row {
        anchors.top: canvas.bottom
        anchors.topMargin: units.gu(1)
        anchors.horizontalCenter: parent.horizontalCenter
        width: canvas.width
        spacing: units.gu(1)

        Label {
            text: formatTime(displayPositionMs())
            color: Theme.primary
            font.pixelSize: units.gu(1.6)
            width: units.gu(6)
            horizontalAlignment: Text.AlignLeft
        }

        Item { width: parent.width - units.gu(16); height: 1 }

        Label {
            text: "-" + formatTime(remainingTimeMs())
            color: "#888888"
            font.pixelSize: units.gu(1.6)
            width: units.gu(6)
            horizontalAlignment: Text.AlignRight
        }
    }
}
