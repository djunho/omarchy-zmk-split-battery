import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.djunho.zmk-split-battery"

  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  // The script prints the central half first; centralSide says which physical side that is.
  readonly property bool centralRight: setting("centralSide", "left") === "right"
  property var labels: ["L", "R"]
  property string status: ""

  function refresh() {
    if (!batteryProc.running) batteryProc.running = true
  }

  visible: status !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: batteryProc
    command: ["bash", root.pluginDir + "/split-battery.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const parts = (text || "").trim().split(/\s+/).filter(p => p !== "")
        if (root.centralRight) parts.reverse()
        // A non-split board reports one level; no side label for it.
        root.status = parts
          .map((p, i) => (parts.length > 1 ? root.labels[i] || "" : "") + p + "%")
          .join(" ")
      }
    }
  }

  // TODO: 5-minute poll; switch to GATT StartNotify if staleness ever matters
  Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf11c " + root.status
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: "ZMK battery — click to refresh"
    onPressed: function() { root.refresh() }
  }
}
