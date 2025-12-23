import QtQuick
import Quickshell.Io
import "./modules/overview"
import "./services"
import "./common"

Item {
    property var pluginApi: null

    onPluginApiChanged: updateConfig()
    Component.onCompleted: updateConfig()

    function updateConfig() {
        if (!pluginApi)
            return;
        var s = pluginApi.pluginSettings || {};
        var d = pluginApi.manifest?.metadata?.defaultSettings || {};

        Config.options.overview.rows = s.rows ?? d.rows ?? Config.options.overview.rows;
        Config.options.overview.columns = s.columns ?? d.columns ?? Config.options.overview.columns;
        Config.options.overview.scale = s.scale ?? d.scale ?? Config.options.overview.scale;
        Config.options.overview.topMargin = s.topMargin ?? d.topMargin ?? Config.options.overview.topMargin;
        Config.options.overview.centerIcons = s.centerIcons ?? d.centerIcons ?? Config.options.overview.centerIcons;
    }

    Overview {}

    IpcHandler {
        target: "plugin:quickshell-overview"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
    }
}
