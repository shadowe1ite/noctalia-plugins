import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "services"

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 500 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string githubToken: cfg.githubToken || defaults.githubToken || ""

    // Trigger refresh when panel becomes visible
    onVisibleChanged: {
        if (visible && githubToken && !GitHubService.loading) {
            GitHubService.refresh();
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                    icon: "brand-github"
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                }

                NText {
                    Layout.fillWidth: true
                    text: pluginApi?.tr("widget.title", "GitHub Notifications") || "GitHub Notifications"
                    pointSize: Style.fontSizeM
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                }

                NIconButton {
                    icon: "bookmarks"
                    enabled: GitHubService.unreadCount > 0 && !GitHubService.loading
                    tooltipText: pluginApi?.tr("widget.markAllRead", "Mark all as read") || "Mark all as read"
                    onClicked: GitHubService.markAllAsRead()
                }

                NIconButton {
                    icon: "refresh"
                    enabled: !GitHubService.loading
                    colorFg: GitHubService.loading ? Color.mOnSurfaceVariant : Color.mOnSurface
                    tooltipText: pluginApi?.tr("widget.refresh", "Refresh") || "Refresh"
                    onClicked: GitHubService.refresh()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: GitHubService.notifications.length > 0

                NText {
                    Layout.fillWidth: true
                    text: {
                        var count = GitHubService.notifications.length;
                        var text = count + " notifications";
                        if (GitHubService.unreadCount > 0)
                            text += " • " + GitHubService.unreadCount + " unread";
                        return text;
                    }
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                // No token state
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginL
                    visible: !githubToken

                    NIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "user-circle"
                        pointSize: Style.fontSizeXXL * 2
                        color: Color.mOnSurfaceVariant
                    }

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Token not configured"
                        pointSize: Style.fontSizeM
                        font.weight: Font.Medium
                        color: Color.mOnSurface
                    }
                }

                // Error state
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginL
                    visible: GitHubService.error && githubToken

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: GitHubService.errorMessage || "Failed to fetch notifications"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                    }
                }

                // Loading state
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginL
                    visible: GitHubService.loading && GitHubService.notifications.length === 0

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: pluginApi?.tr("widget.loading", "Loading...") || "Loading..."
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                    }
                }

                // Empty list
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginL
                    visible: !GitHubService.loading && !GitHubService.error && GitHubService.notifications.length === 0 && githubToken

                    NText {
                        Layout.alignment: Qt.AlignHCenter
                        text: pluginApi?.tr("widget.no-notifications", "No notifications") || "No notifications"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                    }
                }

                NScrollView {
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    visible: GitHubService.notifications.length > 0 && !GitHubService.error

                    ListView {
                        model: GitHubService.notifications
                        spacing: Style.marginS
                        clip: true

                        delegate: Rectangle {
                            id: notifCard
                            width: ListView.view.width
                            height: cardContent.implicitHeight + Style.marginM * 2
                            color: cardMouse.containsMouse ? Qt.lighter(Color.mSurface, 1.05) : Color.mSurface
                            radius: Style.radiusM

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            property var notification: modelData

                            Rectangle {
                                visible: notification.unread
                                width: 3
                                height: parent.height - 16
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                color: Color.mPrimary
                                radius: 2
                            }

                            RowLayout {
                                id: cardContent
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    margins: Style.marginM
                                    leftMargin: notification.unread ? Style.marginM + 6 : Style.marginM
                                }
                                spacing: Style.marginM

                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    Layout.alignment: Qt.AlignTop
                                    radius: 18
                                    color: Qt.alpha(Color.mOnSurface, 0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: getNotificationIcon(notification)
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: Style.fontSizeL
                                        color: notification.unread ? Color.mPrimary : Color.mOnSurfaceVariant
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        NText {
                                            text: notification.repository?.full_name || ""
                                            pointSize: Style.fontSizeS
                                            font.weight: Font.Bold
                                            color: Color.mOnSurface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        NText {
                                            text: formatRelativeTime(notification.updated_at)
                                            pointSize: Style.fontSizeXS
                                            color: Color.mOnSurfaceVariant
                                        }
                                    }

                                    NText {
                                        Layout.fillWidth: true
                                        text: notification.subject?.title || ""
                                        pointSize: Style.fontSizeS
                                        color: notification.unread ? Color.mOnSurface : Color.mOnSurfaceVariant
                                        font.weight: notification.unread ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    // Open URL first before marking as read
                                    // (markAsRead triggers array update which can invalidate notification reference)
                                    var url = notification.subject?.url ? convertApiUrlToWeb(notification) : "";
                                    var isUnread = notification.unread;
                                    var notifId = notification.id;

                                    if (url) {
                                        Qt.openUrlExternally(url);
                                    }
                                    if (isUnread) {
                                        GitHubService.markAsRead(notifId);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function getNotificationIcon(notification) {
        const type = notification.subject?.type || "";
        switch (type) {
        case "Issue":
            return "\uf41b";
        case "PullRequest":
            return "\uea64";
        case "Release":
            return "\uea84";
        case "CheckSuite":
            return "\uf418";
        case "Discussion":
            return "\uf442";
        default:
            return "\uf0a1";
        }
    }

    function formatRelativeTime(isoString) {
        if (!isoString)
            return "";
        var date = new Date(isoString);
        var now = new Date();
        var diffMs = now - date;
        var diffSec = Math.floor(diffMs / 1000);
        var diffMin = Math.floor(diffSec / 60);
        var diffHour = Math.floor(diffMin / 60);
        var diffDay = Math.floor(diffHour / 24);

        if (diffMin < 1)
            return "now";
        if (diffMin < 60)
            return diffMin + "m ago";
        if (diffHour < 24)
            return diffHour + "h ago";
        return diffDay + "d ago";
    }

    function convertApiUrlToWeb(notification) {
        const url = notification.subject?.url || "";
        if (url.includes("/repos/")) {
            return url.replace("api.github.com/repos/", "github.com/").replace("/pulls/", "/pull/").replace("/issues/", "/issues/");
        }
        return url;
    }
}
