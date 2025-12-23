import QtQuick
import Quickshell
import "./modules"

Item {
    id: root

    property var pluginApi: null

    Hyprview {
        id: view
        pluginApi: root.pluginApi
    }
}
