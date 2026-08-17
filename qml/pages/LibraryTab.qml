import QtQuick 2.9
import Ubuntu.Components 1.3
import "../js/Theme.js" as Theme

PageStack {
    id: libraryTabStack
    
    Component.onCompleted: {
        libraryTabStack.push(Qt.resolvedUrl("LibraryPage.qml"));
    }
}
