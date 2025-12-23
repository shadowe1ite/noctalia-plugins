import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/functions"
import "../../services"

Item {
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property real winScale: 0.16
    property var availableWorkspaceWidth
    property var availableWorkspaceHeight
    property bool restrictToWorkspace: true

    // [NEW] Controls how much to increase the rounding.
    readonly property real roundingMultiplier: 1

    property bool isFullscreen: windowData?.fullscreen ?? false

    property real initX: (isFullscreen ? 0 : Math.max(((windowData?.at[0] ?? 0) - (monitorData?.x ?? 0)) * root.winScale, 0)) + xOffset
    property real initY: (isFullscreen ? 0 : Math.max(((windowData?.at[1] ?? 0) - (monitorData?.y ?? 0)) * root.winScale, 0)) + yOffset

    property real xOffset: 0
    property real yOffset: 0
    property int widgetMonitorId: 0

    property var targetWindowWidth: (windowData?.size[0] ?? 100) * winScale
    property var targetWindowHeight: (windowData?.size[1] ?? 100) * winScale
    property bool hovered: false
    property bool pressed: false

    property bool centerIcons: Config.options.overview.centerIcons
    property var iconToWindowRatio: centerIcons ? 0.25 : 0.25
    property var iconGapRatio: 0.06
    property var xwaylandIndicatorToIconRatio: 0.35
    property var iconToWindowRatioCompact: 0.45

    property var entry: DesktopEntries.heuristicLookup(windowData?.class)
    property var iconPath: Quickshell.iconPath(entry?.icon ?? windowData?.class ?? "application-x-executable", "image-missing")
    property bool compactMode: Appearance.font.pixelSize.smaller * 4 > targetWindowHeight || Appearance.font.pixelSize.smaller * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false

    x: initX
    y: initY

    width: isFullscreen ? availableWorkspaceWidth : Math.min((windowData?.size[0] ?? 100) * root.winScale, availableWorkspaceWidth)
    height: isFullscreen ? availableWorkspaceHeight : Math.min((windowData?.size[1] ?? 100) * root.winScale, availableWorkspaceHeight)

    opacity: (windowData?.monitor ?? -1) == widgetMonitorId ? 1 : 0.4

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            // [FIX] Multiply Hyprland's rounding by our multiplier
            radius: (isFullscreen ? 0 : HyprlandData.rounding) * root.winScale * root.roundingMultiplier
        }
    }

    Behavior on x {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on y {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on width {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on height {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: GlobalStates.overviewOpen ? root.toplevel : null
        live: true

        Rectangle {
            anchors.fill: parent
            // [FIX] Multiply here as well
            radius: (isFullscreen ? 0 : HyprlandData.rounding) * root.winScale * root.roundingMultiplier

            color: pressed ? ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.5) : hovered ? ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.7) : ColorUtils.transparentize(Appearance.colors.colLayer2)
            border.color: ColorUtils.transparentize(Appearance.m3colors.m3outline, 0.7)
            border.width: 1
        }

        Image {
            id: windowIcon
            property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)

            anchors {
                top: root.centerIcons ? undefined : parent.top
                left: root.centerIcons ? undefined : parent.left
                centerIn: root.centerIcons ? parent : undefined
                margins: baseSize * root.iconGapRatio
            }

            property var iconSize: {
                return Math.min(targetWindowWidth, targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / (root.monitorData?.scale ?? 1);
            }

            source: root.iconPath
            width: iconSize
            height: iconSize
            sourceSize: Qt.size(iconSize, iconSize)

            Behavior on width {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
            Behavior on height {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
        }
    }
}
