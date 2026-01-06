import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string githubToken: cfg.githubToken || defaults.githubToken || ""
  readonly property int checkInterval: cfg.checkInterval ?? defaults.checkInterval ?? 300
  readonly property bool showOnlyUnread: cfg.showOnlyUnread ?? defaults.showOnlyUnread ?? false
  readonly property int maxNotifications: cfg.maxNotifications ?? defaults.maxNotifications ?? 30

  // State
  property var notifications: []
  property int unreadCount: 0
  property bool loading: false
  property bool error: false
  property string errorMessage: ""

  // Visual Styling
  icon: "brand-github"
  baseSize: Style.capsuleHeight
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: error ? Color.mError : Color.mOnSurface
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: "transparent"
  colorBorderHover: "transparent"

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  tooltipText: {
    if (!githubToken)
      return "GitHub Notifications\nToken not configured";
    if (loading)
      return "GitHub Notifications\nLoading...";
    if (error)
      return "GitHub Notifications\nError: " + (errorMessage || "Unknown");

    var text = "GitHub Notifications";
    if (unreadCount > 0)
      text += "\n" + unreadCount + " unread";
    else
      text += "\nNo new notifications";

    text += "\nRight-click to refresh";
    return text;
  }
  tooltipDirection: BarService.getTooltipDirection()

  // Green Dot Indicator
  Rectangle {
    visible: unreadCount > 0
    width: 8
    height: 8
    radius: 4
    color: Color.mSuccess

    anchors {
      top: parent.top
      right: parent.right
      topMargin: 3
      rightMargin: 3
    }

    border.width: 2
    border.color: root.colorBg
  }

  // --- Logic Implementation ---

  onNotificationsChanged: {
    if (pluginApi) {
      pluginApi.sharedData = pluginApi.sharedData || {};
      pluginApi.sharedData.notifications = notifications;
    }
  }
  onLoadingChanged: {
    if (pluginApi) {
      pluginApi.sharedData = pluginApi.sharedData || {};
      pluginApi.sharedData.loading = loading;
    }
  }
  onErrorChanged: {
    if (pluginApi) {
      pluginApi.sharedData = pluginApi.sharedData || {};
      pluginApi.sharedData.error = error;
    }
  }
  onErrorMessageChanged: {
    if (pluginApi) {
      pluginApi.sharedData = pluginApi.sharedData || {};
      pluginApi.sharedData.errorMessage = errorMessage;
    }
  }

  Component.onCompleted: {
    if (pluginApi) {
      pluginApi.sharedData = pluginApi.sharedData || {};
      pluginApi.triggerRefresh = fetchNotifications;
      pluginApi.markAsRead = markAsRead;
      pluginApi.markAllAsRead = markAllAsRead;
    }

    Logger.i("GitHubNotifications", "BarWidget initialized");
  }

  // Timer for periodic updates
  Timer {
    id: updateTimer
    interval: checkInterval * 1000
    // Timer runs only when token exists
    running: githubToken !== ""
    repeat: true
    // Important: This ensures it fetches immediately when 'running' becomes true (when token loads)
    triggeredOnStart: true
    onTriggered: {
      fetchNotifications();
    }
  }

  Process {
    id: fetchProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    property bool isFetching: false

    onExited: exitCode => {
                if (!isFetching)
                return;
                isFetching = false;
                loading = false;

                if (exitCode !== 0 || !stdout.text || stdout.text.trim() === "") {
                  error = true;
                  return;
                }

                try {
                  const data = JSON.parse(stdout.text);
                  if (data && data.message) {
                    error = true;
                    errorMessage = data.message;
                    notifications = [];
                    unreadCount = 0;
                    return;
                  }

                  if (Array.isArray(data)) {
                    notifications = data;
                    unreadCount = data.filter(n => n.unread).length;
                  } else {
                    error = true;
                  }
                } catch (e) {
                  error = true;
                }
              }
  }

  Process {
    id: markReadProcess
    running: false
    stdout: StdioCollector {}

    onExited: exitCode => {
                if (exitCode === 0) {
                  fetchNotifications();
                }
              }
  }

  Process {
    id: markAllReadProcess
    running: false
    stdout: StdioCollector {}

    onExited: exitCode => {
                if (exitCode === 0) {
                  fetchNotifications();
                }
              }
  }

  // Interaction Handlers
  onClicked: {
    for (var slot = 1; slot <= 2; slot++) {
      var panel = PanelService.getPanel("pluginPanel" + slot, screen);
      if (panel && panel.currentPluginId === "github-notifications") {
        panel.toggle(root);
        return;
      }
    }

    for (var slot = 1; slot <= 2; slot++) {
      var panel = PanelService.getPanel("pluginPanel" + slot, screen);
      if (panel && panel.currentPluginId === "") {
        panel.currentPluginId = "github-notifications";
        panel.loadPluginPanel("github-notifications");
        panel.open(root);
        return;
      }
    }

    var panel1 = PanelService.getPanel("pluginPanel1", screen);
    if (panel1) {
      panel1.unloadPluginPanel();
      panel1.currentPluginId = "github-notifications";
      panel1.loadPluginPanel("github-notifications");
      panel1.open(root);
    }
  }

  onRightClicked: {
    fetchNotifications();
    ToastService.showNotice("Refreshing GitHub notifications...");
  }

  function fetchNotifications() {
    if (!githubToken || loading)
      return;
    loading = true;
    error = false;
    errorMessage = "";

    const url = showOnlyUnread ? "https://api.github.com/notifications" : "https://api.github.com/notifications?all=true";
    fetchProcess.command = ["curl", "-s", "-H", "Authorization: token " + githubToken, "-H", "Accept: application/vnd.github.v3+json", url];
    fetchProcess.isFetching = true;
    fetchProcess.running = true;
  }

  function markAsRead(notificationId) {
    if (!githubToken)
      return;
    const url = `https://api.github.com/notifications/threads/${notificationId}`;
    markReadProcess.command = ["curl", "-s", "-X", "PATCH", "-H", "Authorization: token " + githubToken, "-H", "Accept: application/vnd.github.v3+json", url];
    markReadProcess.running = true;
  }

  function markAllAsRead() {
    if (!githubToken)
      return;
    const url = "https://api.github.com/notifications";
    markAllReadProcess.command = ["curl", "-s", "-X", "PUT", "-H", "Authorization: token " + githubToken, "-H", "Accept: application/vnd.github.v3+json", url];
    markAllReadProcess.running = true;
  }
}
