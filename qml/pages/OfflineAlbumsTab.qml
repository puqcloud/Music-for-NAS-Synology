import QtQuick 2.9
import Ubuntu.Components 1.3

PageStack {
    id: offlineAlbumsTabStack
    
    Component.onCompleted: {
        offlineAlbumsTabStack.push(Qt.resolvedUrl("OfflineAlbumsPage.qml"));
    }
}
