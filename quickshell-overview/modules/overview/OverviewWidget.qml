import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Services.UI
import "../../common"
import "../../common/functions"
import "../../common/widgets"
import "../../services"

Item {
    id: root

    // [FIX] Ensure we receive the monitor
    required property var monitor

    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns

    // [FIX] Add fallback (?? 1) to prevent "undefined to int" error on startup
    readonly property int workspaceGroup: Math.floor(((monitor.activeWorkspace?.id ?? 1) - 1) / workspacesShown)

    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale

    readonly property bool showWallpaper: Config.options.overview.showWallpaper ?? false

    readonly property real cardPadding: 2

    property color activeBorderColor: Appearance.colors.colSecondary

    property real baseWidth: (monitor.transform % 2 === 1) ? monitor.height : monitor.width
    property real baseHeight: (monitor.transform % 2 === 1) ? monitor.width : monitor.height
    property real workspaceImplicitWidth: Math.floor(baseWidth * root.scale)
    property real workspaceImplicitHeight: Math.floor(baseHeight * root.scale)

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999

    property real workspaceSpacing: Math.max(HyprlandData.gapsIn * root.scale, 5)

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen && root.showWallpaper) {
                sharedWallpaper.source = "file://" + WallpaperService.getWallpaper(root.monitor.name);
            }
        }
    }

    Image {
        id: sharedWallpaper
        visible: false
        source: root.showWallpaper ? "file://" + WallpaperService.getWallpaper(root.monitor.name) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        mipmap: false
        smooth: true
    }

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle {
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: Appearance.rounding.screenRounding * root.scale + padding
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true

        ColumnLayout {
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            Repeater {
                model: Config.options.overview.rows
                delegate: RowLayout {
                    id: row
                    property int rowIndex: index
                    spacing: workspaceSpacing

                    Repeater {
                        model: Config.options.overview.columns
                        Rectangle {
                            id: workspace
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * workspacesShown + rowIndex * Config.options.overview.columns + colIndex + 1
                            property color defaultWorkspaceColor: Appearance.colors.colLayer1
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight

                            color: root.showWallpaper ? "transparent" : (hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor)

                            radius: Appearance.rounding.windowRounding
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            ShaderEffect {
                                visible: root.showWallpaper
                                anchors.fill: parent
                                anchors.margins: parent.border.width

                                property variant source: sharedWallpaper
                                property real itemWidth: width
                                property real itemHeight: height

                                property real sourceWidth: sharedWallpaper.sourceSize.width
                                property real sourceHeight: sharedWallpaper.sourceSize.height
                                property real cornerRadius: Math.max(0, parent.radius - parent.border.width)
                                property real imageOpacity: 1.0
                                property int fillMode: Image.PreserveAspectCrop

                                fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/rounded_image.frag.qsb")
                                blending: true
                            }

                            StyledText {
                                visible: !root.showWallpaper
                                anchors.centerIn: parent
                                text: workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false;
                                        Hyprland.dispatch(`workspace ${workspaceValue}`);
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspaceValue;
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace)
                                        return;
                                    hoveredWhileDragging = true;
                                }
                                onExited: {
                                    hoveredWhileDragging = false;
                                    if (root.draggingTargetWorkspace == workspaceValue)
                                        root.draggingTargetWorkspace = -1;
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater {
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter(toplevel => {
                            const address = `0x${toplevel.HyprlandToplevel.address}`;
                            var win = windowByAddress[address];
                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown);
                            return inWorkspaceGroup;
                        }).sort((a, b) => {
                            const addrA = `0x${a.HyprlandToplevel.address}`;
                            const addrB = `0x${b.HyprlandToplevel.address}`;

                            const winA = windowByAddress[addrA];
                            const winB = windowByAddress[addrB];

                            if (winA?.pinned !== winB?.pinned)
                                return winA?.pinned ? 1 : -1;
                            if (winA?.fullscreen !== winB?.fullscreen)
                                return winA?.fullscreen ? 1 : -1;
                            if (winA?.floating !== winB?.floating)
                                return winA?.floating ? 1 : -1;
                            if ((winA?.focusHistoryID ?? 999) === 0)
                                return 1;
                            if ((winB?.focusHistoryID ?? 999) === 0)
                                return -1;

                            const indexA = HyprlandData.windowList.findIndex(w => w.address === addrA);
                            const indexB = HyprlandData.windowList.findIndex(w => w.address === addrB);
                            return indexA - indexB;
                        });
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    required property int index
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id === monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    windowData: windowByAddress[address]
                    toplevel: modelData
                    monitorData: monitor

                    property bool isFullscreen: windowData?.fullscreen ?? false

                    property real sourceMonitorWidth: (monitor?.transform % 2 === 1) ? ((monitor?.height ?? 1920) / (monitor?.scale ?? 1)) : ((monitor?.width ?? 1920) / (monitor?.scale ?? 1))

                    property real sourceMonitorHeight: (monitor?.transform % 2 === 1) ? ((monitor?.width ?? 1080) / (monitor?.scale ?? 1)) : ((monitor?.height ?? 1080) / (monitor?.scale ?? 1))

                    winScale: isFullscreen ? Math.min(root.workspaceImplicitWidth / sourceMonitorWidth, root.workspaceImplicitHeight / sourceMonitorHeight) : Math.min((root.workspaceImplicitWidth - root.cardPadding * 2) / sourceMonitorWidth, (root.workspaceImplicitHeight - root.cardPadding * 2) / sourceMonitorHeight)

                    property real contentWidth: sourceMonitorWidth * winScale
                    property real contentHeight: sourceMonitorHeight * winScale

                    property real centeringX: isFullscreen ? 0 : (availableWorkspaceWidth - contentWidth) / 2
                    property real centeringY: isFullscreen ? 0 : (availableWorkspaceHeight - contentHeight) / 2

                    availableWorkspaceWidth: isFullscreen ? root.workspaceImplicitWidth : (root.workspaceImplicitWidth - root.cardPadding * 2)
                    availableWorkspaceHeight: isFullscreen ? root.workspaceImplicitHeight : (root.workspaceImplicitHeight - root.cardPadding * 2)

                    widgetMonitorId: root.monitor.id

                    property bool atInitPosition: (initX == x && initY == y)

                    property int workspaceColIndex: (windowData?.workspace.id - 1) % Config.options.overview.columns
                    property int workspaceRowIndex: Math.floor((windowData?.workspace.id - 1) % root.workspacesShown / Config.options.overview.columns)

                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex + (isFullscreen ? 0 : root.cardPadding) + centeringX
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex + (isFullscreen ? 0 : root.cardPadding) + centeringY

                    width: isFullscreen ? root.workspaceImplicitWidth : Math.min((windowData?.size[0] ?? 100) * winScale, contentWidth)
                    height: isFullscreen ? root.workspaceImplicitHeight : Math.min((windowData?.size[1] ?? 100) * winScale, contentHeight)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            var relX = (windowData?.at[0] ?? 0) - (monitor?.x ?? 0);
                            var relY = (windowData?.at[1] ?? 0) - (monitor?.y ?? 0);
                            window.x = Math.round(Math.max(relX * window.winScale, 0) + xOffset);
                            window.y = Math.round(Math.max(relY * window.winScale, 0) + yOffset);
                        }
                    }

                    z: root.windowZ + index + (window.pressed ? 100 : 0)

                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true
                        onExited: hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: mouse => {
                            root.draggingFromWorkspace = windowData?.workspace.id;
                            window.pressed = true;
                            window.Drag.active = true;
                            window.Drag.source = window;
                            window.Drag.hotSpot.x = mouse.x;
                            window.Drag.hotSpot.y = mouse.y;
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace;
                            window.pressed = false;
                            window.Drag.active = false;
                            root.draggingFromWorkspace = -1;

                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`);
                                updateWindowPosition.restart();
                            } else {
                                if (!window.windowData.floating) {
                                    updateWindowPosition.restart();
                                    return;
                                }
                                const percentageX = Math.round((window.x - xOffset) / (root.workspaceImplicitWidth - root.cardPadding * 2) * 100);
                                const percentageY = Math.round((window.y - yOffset) / (root.workspaceImplicitHeight - root.cardPadding * 2) * 100);

                                Hyprland.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${window.windowData?.address}`);
                            }
                        }
                        onClicked: event => {
                            if (!windowData)
                                return;
                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false;
                                Hyprland.dispatch(`focuswindow address:${windowData.address}`);
                                event.accepted = true;
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`);
                                event.accepted = true;
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title ?? "Unknown"}\n[${windowData?.class ?? "unknown"}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle {
                id: focusedWorkspaceIndicator
                property int activeWorkspaceInGroup: monitor.activeWorkspace?.id - (root.workspaceGroup * root.workspacesShown)
                property int activeWorkspaceRowIndex: Math.floor((activeWorkspaceInGroup - 1) / Config.options.overview.columns)
                property int activeWorkspaceColIndex: (activeWorkspaceInGroup - 1) % Config.options.overview.columns
                x: (root.workspaceImplicitWidth + workspaceSpacing) * activeWorkspaceColIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * activeWorkspaceRowIndex

                z: root.windowZ + 99

                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"

                radius: Appearance.rounding.windowRounding

                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }
    }
}
