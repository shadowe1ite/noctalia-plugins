import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../tabs"
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: stegRoot

  // --- State ---
  property string selectedImage: ""
  property bool isScanning: false
  property var toolQueue: []
  property string currentToolName: ""

  // --- Data Model ---
  ListModel {
    id: resultsModel
  }

  // --- Process Handler ---
  Process {
    id: stegProcess

    stdout: StdioCollector {
      onStreamFinished: {
        if (stegRoot.currentToolName !== "") {
          stegRoot.updateResult(stegRoot.currentToolName, text);
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "") {
          var idx = stegRoot.findResultIndex(stegRoot.currentToolName);
          if (idx !== -1) {
            var oldText = resultsModel.get(idx).output;
            resultsModel.setProperty(idx, "output", oldText + "\n[STDERR]\n" + text);
          }
        }
      }
    }

    onExited: {
      stegRoot.processNextTool();
    }
  }

  // --- Logic Functions ---
  function startFullScan() {
    if (stegRoot.selectedImage === "")
      return;

    stegRoot.isScanning = true;
    resultsModel.clear();

    stegRoot.toolQueue = [
          {
            name: "File Type",
            cmd: ["file", stegRoot.selectedImage],
            icon: "file-unknown"
          },
          {
            name: "Exif Metadata",
            cmd: ["exiftool", stegRoot.selectedImage],
            icon: "info-triangle"
          },
          {
            name: "Binwalk Signatures",
            cmd: ["binwalk", stegRoot.selectedImage],
            icon: "binary"
          },
          {
            name: "Steghide Info",
            cmd: ["steghide", "info", "-p", "", stegRoot.selectedImage],
            icon: "photo-search"
          },
          {
            name: "Strings (Top 200)",
            cmd: ["bash", "-c", "strings -n 5 '" + stegRoot.selectedImage + "' | head -n 200"],
            icon: "file-description"
          }
        ];

    stegRoot.processNextTool();
  }

  function processNextTool() {
    if (stegRoot.toolQueue.length === 0) {
      stegRoot.isScanning = false;
      stegRoot.currentToolName = "";
      return;
    }

    var tool = stegRoot.toolQueue.shift();
    stegRoot.currentToolName = tool.name;

    resultsModel.append({
                          name: tool.name,
                          icon: tool.icon,
                          output: "",
                          loading: true
                        });

    stegProcess.command = tool.cmd;
    stegProcess.running = true;
  }

  function updateResult(name, outputText) {
    var idx = stegRoot.findResultIndex(name);
    if (idx !== -1) {
      resultsModel.setProperty(idx, "output", outputText.trim());
      resultsModel.setProperty(idx, "loading", false);
    }
  }

  function findResultIndex(name) {
    for (var i = 0; i < resultsModel.count; i++) {
      if (resultsModel.get(i).name === name)
        return i;
    }
    return -1;
  }

  // --- UI Layout ---
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // Header Area
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      Rectangle {
        width: 64
        height: 64
        radius: Style.radiusM
        color: Color.mSurfaceVariant
        clip: true

        NIcon {
          visible: stegRoot.selectedImage === ""
          anchors.centerIn: parent
          icon: "image"
          color: Color.mOnSurfaceVariant
        }
        Image {
          visible: stegRoot.selectedImage !== ""
          anchors.fill: parent
          source: stegRoot.selectedImage !== "" ? "file://" + stegRoot.selectedImage : ""
          fillMode: Image.PreserveAspectCrop
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: stegRoot.selectedImage !== "" ? stegRoot.selectedImage : "Select an image"
          elide: Text.ElideMiddle
          Layout.fillWidth: true
          color: Color.mOnSurface
          font.weight: Font.Bold
        }

        RowLayout {
          NButton {
            text: "Browse"
            icon: "folder-open"
            onClicked: imagePicker.open()
            enabled: !stegRoot.isScanning
          }
          NButton {
            text: stegRoot.isScanning ? "Scanning..." : "Deep Scan"
            icon: stegRoot.isScanning ? "loader" : "search"
            color: Color.mPrimary
            enabled: stegRoot.selectedImage !== "" && !stegRoot.isScanning
            onClicked: stegRoot.startFullScan()
          }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Color.mOutline
      opacity: 0.5
    }

    // Results List
    ListView {
      id: resultList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: resultsModel
      spacing: Style.marginM

      delegate: Rectangle {
        id: resultCard
        width: ListView.view.width
        // Fix: Height is dynamic based on content + padding
        height: contentCol.implicitHeight + (Style.marginM * 2)
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        property bool expanded: false

        ColumnLayout {
          id: contentCol
          width: parent.width - (Style.marginM * 2)
          anchors.centerIn: parent
          spacing: Style.marginS

          // Title Row
          RowLayout {
            Layout.fillWidth: true
            NIcon {
              icon: model.icon
              color: Color.mPrimary
            }
            NText {
              text: model.name
              font.weight: Font.Bold
              Layout.fillWidth: true
            }

            NBusyIndicator {
              running: model.loading
              visible: model.loading
              size: 20 // Fixed property name
            }

            NIconButton {
              visible: !model.loading
              icon: resultCard.expanded ? "chevron-up" : "chevron-down"
              onClicked: resultCard.expanded = !resultCard.expanded
            }
          }

          // Output Box
          Rectangle {
            Layout.fillWidth: true
            // Fix: Calculate height only when visible
            Layout.preferredHeight: visible ? (contentText.implicitHeight + 20) : 0

            visible: resultCard.expanded && !model.loading && model.output !== ""
            color: Color.mSurface
            radius: Style.radiusS
            clip: true

            TextEdit {
              id: contentText
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 10

              text: model.output
              font.family: "Monospace"
              font.pointSize: 10
              color: Color.mOnSurfaceVariant
              wrapMode: Text.Wrap

              // Enable Selection
              readOnly: true
              selectByMouse: true
              selectionColor: Color.mPrimary
              selectedTextColor: Color.mOnPrimary
            }
          }

          NText {
            visible: !model.loading && model.output === ""
            text: "No output found."
            font.italic: true
            color: Color.mOutline
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }
  }

  NFilePicker {
    id: imagePicker
    title: "Select Image"
    selectionMode: "files"
    nameFilters: ImageCacheService.imageFilters
    initialPath: Quickshell.env("HOME")
    onAccepted: paths => {
                  if (paths.length > 0) {
                    stegRoot.selectedImage = paths[0];
                    resultsModel.clear();
                  }
                }
  }
}
