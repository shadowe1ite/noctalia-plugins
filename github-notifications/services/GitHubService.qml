pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    // Configuration - set by BarWidget on init
    property string githubToken: ""
    property int checkInterval: 300
    property bool showOnlyUnread: false
    property int maxNotifications: 30

    // Shared state - both BarWidget and Panel read from here
    property var notifications: []
    property int unreadCount: 0
    property bool loading: false
    property bool error: false
    property string errorMessage: ""

    // Fetch process
    property var _fetchProcess: Process {
        id: fetchProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        property bool isFetching: false

        onExited: exitCode => {
            if (!isFetching)
                return;
            isFetching = false;
            service.loading = false;

            if (exitCode !== 0 || !stdout.text || stdout.text.trim() === "") {
                service.error = true;
                service.errorMessage = "Failed to fetch";
                return;
            }

            try {
                const data = JSON.parse(stdout.text);
                if (data && data.message) {
                    service.error = true;
                    service.errorMessage = data.message;
                    service.notifications = [];
                    service.unreadCount = 0;
                    return;
                }

                if (Array.isArray(data)) {
                    service.notifications = data.slice(0, service.maxNotifications);
                    service.unreadCount = data.filter(n => n.unread).length;
                    service.error = false;
                    service.errorMessage = "";
                } else {
                    service.error = true;
                    service.errorMessage = "Invalid response";
                }
            } catch (e) {
                service.error = true;
                service.errorMessage = "Parse error";
            }
        }
    }

    // Mark single notification as read
    property var _markReadProcess: Process {
        id: markReadProcess
        running: false
        stdout: StdioCollector {}

        onExited: exitCode => {
            service.refresh();
        }
    }

    // Mark all as read
    property var _markAllReadProcess: Process {
        id: markAllReadProcess
        running: false
        stdout: StdioCollector {}

        onExited: exitCode => {
            service.refresh();
        }
    }

    function refresh() {
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

        // Optimistic update
        var updated = [];
        for (var i = 0; i < notifications.length; i++) {
            var notif = notifications[i];
            if (notif.id === notificationId) {
                var copy = JSON.parse(JSON.stringify(notif));
                copy.unread = false;
                updated.push(copy);
            } else {
                updated.push(notif);
            }
        }
        notifications = updated;
        unreadCount = updated.filter(n => n.unread).length;

        // API call
        const url = "https://api.github.com/notifications/threads/" + notificationId;
        markReadProcess.command = ["curl", "-s", "-X", "PATCH", "-H", "Authorization: token " + githubToken, "-H", "Accept: application/vnd.github.v3+json", url];
        markReadProcess.running = true;
    }

    function markAllAsRead() {
        if (!githubToken)
            return;

        // Optimistic update
        var updated = [];
        for (var i = 0; i < notifications.length; i++) {
            var copy = JSON.parse(JSON.stringify(notifications[i]));
            copy.unread = false;
            updated.push(copy);
        }
        notifications = updated;
        unreadCount = 0;

        // API call
        const url = "https://api.github.com/notifications";
        markAllReadProcess.command = ["curl", "-s", "-X", "PUT", "-H", "Authorization: token " + githubToken, "-H", "Accept: application/vnd.github.v3+json", url];
        markAllReadProcess.running = true;
    }
}
