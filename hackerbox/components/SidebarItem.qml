import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Rectangle {
  id: sideItem

  // Define the signal so the parent can listen to it
  signal activated(int index)

  // Data properties (marked required to match Repeater context automatically)
  required property var modelData
  required property int index

  // Config properties (mapped manually from parent)
  property int currentTabIndex: 0
  property bool sidebarExpanded: false
  property string iconName: modelData.icon
  property string itemText: modelData.text
  property int idx: index

  Layout.fillWidth: true
  Layout.preferredHeight: 40 * Style.uiScaleRatio
  radius: Style.radiusS

  color: currentTabIndex === idx ? Qt.rgba(1, 1, 1, 0.1) : itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Color.transparent

  // Active indicator bar
  Rectangle {
    visible: currentTabIndex === sideItem.idx
    width: 3
    height: 16
    radius: 2
    color: Color.mPrimary
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
      leftMargin: 4
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    spacing: 12

    NIcon {
      icon: sideItem.iconName
      color: currentTabIndex === sideItem.idx ? Color.mPrimary : Color.mOnSurface
      Layout.preferredWidth: 24
      Layout.preferredHeight: 24
    }

    Text {
      text: sideItem.itemText
      color: currentTabIndex === sideItem.idx ? Color.mPrimary : Color.mOnSurface
      font.weight: currentTabIndex === sideItem.idx ? Font.DemiBold : Font.Normal
      opacity: sidebarExpanded ? 1 : 0
      Layout.fillWidth: true
      elide: Text.ElideRight

      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }
    }
  }

  MouseArea {
    id: itemMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // Emit signal instead of accessing root directly
    onClicked: sideItem.activated(sideItem.idx)
  }
}
