#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include "filehelper.h"

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsSet("CLICKABLE_DESKTOP_MODE")) {
        qputenv("PULSE_SERVER", "unix:/run/user/1000/pulse/native");
    }

    QGuiApplication app(argc, argv);
    
    // In Ubuntu Touch Focal, the desktop file is exactly <package>_<hook>.desktop
    // This allows the sound indicator to find the app and raise it.
    app.setDesktopFileName("music-for-nas-synology.puqsoftware_music-for-nas-synology");
    app.setApplicationName("music-for-nas-synology.puqsoftware");

    FileHelper fileHelper;

    QQuickView view;
    view.engine()->rootContext()->setContextProperty("FileHelper", &fileHelper);
    view.setSource(QUrl(QStringLiteral("qml/Main.qml")));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.show();

    return app.exec();
}
