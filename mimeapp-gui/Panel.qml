import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance ?? null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 900 * Style.uiScaleRatio
  property real contentPreferredHeight: 700 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  property string backendPath: ""
  property bool loading: false
  property bool applying: false
  property string statusMessage: ""
  property int pendingApplyIndex: -1
  property int selectedGroupIndex: 0
  property var groupTabs: [
    { "key": "common", "name": "Default", "count": 0 },
    { "key": "all", "name": "All MimeTypes", "count": 0 }
  ]

  property ListModel entriesModel: ListModel {}
  property ListModel filteredEntriesModel: ListModel {}
  property ListModel commonGroupsModel: ListModel {}

  property var applyQueue: []
  property bool batchApplying: false

  readonly property var commonGroupDefinitions: {
    var saved = pluginApi?.pluginSettings?.commonGroups
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings?.commonGroups || []
    if (!saved || saved.length === 0) {
      return defaults
    }

    // If user settings contain only empty mime lists, fall back to defaults.
    for (var i = 0; i < saved.length; i++) {
      var mimeTypes = saved[i]?.mimeTypes || []
      for (var j = 0; j < mimeTypes.length; j++) {
        if (String(mimeTypes[j] || "").trim() !== "") {
          return saved
        }
      }
    }
    return defaults
  }
  readonly property var commonMimeTypes: {
    var defs = commonGroupDefinitions || []
    var types = []
    var seen = {}
    for (var i = 0; i < defs.length; i++) {
      var mimeTypes = defs[i].mimeTypes || []
      for (var j = 0; j < mimeTypes.length; j++) {
        var mimeType = String(mimeTypes[j] || "").trim()
        if (!mimeType || seen[mimeType]) continue
        seen[mimeType] = true
        types.push(mimeType)
      }
    }
    return types
  }
  readonly property var commonTypesMeta: {
    var defs = commonGroupDefinitions || []
    var meta = ({})
    for (var i = 0; i < defs.length; i++) {
      var def = defs[i] || ({})
      var mimeTypes = def.mimeTypes || []
      for (var j = 0; j < mimeTypes.length; j++) {
        var mimeType = String(mimeTypes[j] || "").trim()
        if (!mimeType || meta[mimeType] !== undefined) continue
        meta[mimeType] = {
          groupKey: def.key || mimeType,
          label: def.label || mimeType,
          category: def.category || mimeGroupFromType(mimeType),
          categoryOrder: def.categoryOrder ?? 99
        }
      }
    }
    return meta
  }

  function updateBackendPath() {
    if (!pluginApi || !pluginApi.pluginDir) {
      backendPath = ""
      return
    }
    backendPath = pluginApi.pluginDir + "/mimeapps_backend.py"
  }

  function refreshList() {
    if (loading) return
    if (backendPath === "") {
      statusMessage = "Backend path not ready yet."
      return
    }
    statusMessage = ""
    loading = true

    // Always scan all so the Default tab can show single-handler groups too.
    var args = ["python3", backendPath, "scan", "--all"]

    scanProcess.command = args
    scanProcess.running = true
  }

  function mimeGroupFromType(mimeType) {
    var text = String(mimeType || "")
    var slash = text.indexOf("/")
    if (slash <= 0) return "other"
    return text.substring(0, slash)
  }

  function selectedGroupKey() {
    if (!groupTabs || selectedGroupIndex < 0 || selectedGroupIndex >= groupTabs.length) {
      return "common"
    }
    return groupTabs[selectedGroupIndex].key || "common"
  }

  function commonMetaForMime(mimeType) {
    return commonTypesMeta[mimeType] || {
      groupKey: mimeType,
      label: mimeType,
      category: mimeGroupFromType(mimeType),
      categoryOrder: 99
    }
  }

  function commonGroupKeyForMime(mimeType) {
    return commonMetaForMime(mimeType).groupKey || mimeType
  }

  function mergeHandlers(target, seenKeys, handlers) {
    var source = []
    if (handlers) {
      if (handlers.count !== undefined && handlers.get !== undefined) {
        for (var k = 0; k < handlers.count; k++) {
          source.push(handlers.get(k))
        }
      } else {
        source = handlers
      }
    }
    for (var i = 0; i < source.length; i++) {
      var handler = source[i]
      if (!handler || !handler.key || seenKeys[handler.key]) continue
      seenKeys[handler.key] = true
      target.push(handler)
    }
  }

  function handlersForCommonGroup(sourceIndexes) {
    var handlers = []
    var seenKeys = {}
    var indexes = sourceIndexes || []
    for (var i = 0; i < indexes.length; i++) {
      var sourceIndex = indexes[i]
      if (sourceIndex < 0 || sourceIndex >= entriesModel.count) continue
      mergeHandlers(handlers, seenKeys, entriesModel.get(sourceIndex).handlers)
    }
    return handlers
  }


  function rebuildCommonGroups() {
    commonGroupsModel.clear()

    var groups = {}
    var order = []
    for (var i = 0; i < entriesModel.count; i++) {
      var row = entriesModel.get(i)
      if (commonMimeTypes.indexOf(row.mimeType) === -1) continue

      var meta = commonMetaForMime(row.mimeType)
      var groupKey = meta.groupKey || row.mimeType
      if (!groups[groupKey]) {
        groups[groupKey] = {
          groupKey: groupKey,
          friendlyLabel: meta.label,
          friendlyCategory: meta.category,
          categoryOrder: meta.categoryOrder,
          mimeTypes: [],
          sourceIndexes: [],
          selectedDesktop: "",
          selectionDirty: false,
          applying: false,
          applyError: ""
        }
        order.push(groupKey)
      }

      var group = groups[groupKey]
      group.mimeTypes.push(row.mimeType)
      group.sourceIndexes.push(i)
      if (group.selectedDesktop === "" && row.selectedDesktop) {
        group.selectedDesktop = row.selectedDesktop
      }
      group.selectionDirty = group.selectionDirty || !!row.selectionDirty
      group.applying = group.applying || !!row.applying
      if (group.applyError === "" && row.applyError) {
        group.applyError = row.applyError
      }
    }

    order.sort(function(a, b) {
      var left = groups[a]
      var right = groups[b]
      if (left.categoryOrder !== right.categoryOrder) return left.categoryOrder - right.categoryOrder
      return left.friendlyLabel < right.friendlyLabel ? -1 : (left.friendlyLabel > right.friendlyLabel ? 1 : 0)
    })

    for (var j = 0; j < order.length; j++) {
      var key = order[j]
      var item = groups[key]
      commonGroupsModel.append(item)
    }
  }

  function setCommonGroupSelection(sourceIndexes, desktopId) {
    var indexes = sourceIndexes || []
    for (var i = 0; i < indexes.length; i++) {
      var sourceIndex = indexes[i]
      if (sourceIndex < 0 || sourceIndex >= entriesModel.count) continue
      var currentDefault = entriesModel.get(sourceIndex).currentDefault || ""
      entriesModel.setProperty(sourceIndex, "selectedDesktop", desktopId)
      entriesModel.setProperty(sourceIndex, "selectionDirty", desktopId !== currentDefault)
      entriesModel.setProperty(sourceIndex, "applyError", "")
      syncFilteredRowFromSource(sourceIndex)
    }
    rebuildCommonGroups()
  }

  function rebuildGroupTabs() {
    var commonGroups = {}

    for (var i = 0; i < entriesModel.count; i++) {
      var mimeType = entriesModel.get(i).mimeType
      if (commonMimeTypes.indexOf(mimeType) !== -1) {
        commonGroups[commonGroupKeyForMime(mimeType)] = true
      }
    }

    var tabs = [
      { "key": "common", "name": "Default", "count": Object.keys(commonGroups).length },
      { "key": "all", "name": "All MimeTypes", "count": entriesModel.count }
    ]

    groupTabs = tabs

    selectedGroupIndex = 0
  }

  function rebuildFilteredEntries() {
    filteredEntriesModel.clear()
    rebuildCommonGroups()

    var group = selectedGroupKey()
    var items = []
    for (var i = 0; i < entriesModel.count; i++) {
      var row = entriesModel.get(i)
      var include = (group === "all")
        || (group === "common" && commonMimeTypes.indexOf(row.mimeType) !== -1)
      if (!include) continue

      var meta = commonTypesMeta[row.mimeType] || null
      items.push({
        sourceIndex: i,
        mimeType: row.mimeType,
        handlers: row.handlers,
        currentDefault: row.currentDefault,
        currentDefaultName: row.currentDefaultName,
        defaultSource: row.defaultSource,
        selectedDesktop: row.selectedDesktop,
        selectionDirty: row.selectionDirty,
        applying: row.applying,
        applyError: row.applyError,
        friendlyLabel: meta ? meta.label : row.mimeType,
        friendlyCategory: meta ? meta.category : mimeGroupFromType(row.mimeType),
        categoryOrder: meta ? meta.categoryOrder : 99
      })
    }

    if (group === "common") {
      items.sort(function(a, b) {
        if (a.categoryOrder !== b.categoryOrder) return a.categoryOrder - b.categoryOrder
        return a.friendlyLabel < b.friendlyLabel ? -1 : (a.friendlyLabel > b.friendlyLabel ? 1 : 0)
      })
    }

    for (var j = 0; j < items.length; j++) {
      filteredEntriesModel.append(items[j])
    }
  }

  function syncFilteredRowFromSource(sourceIndex) {
    for (var i = 0; i < filteredEntriesModel.count; i++) {
      var item = filteredEntriesModel.get(i)
      if (item.sourceIndex !== sourceIndex) continue

      var src = entriesModel.get(sourceIndex)
      filteredEntriesModel.setProperty(i, "handlers", src.handlers)
      filteredEntriesModel.setProperty(i, "currentDefault", src.currentDefault)
      filteredEntriesModel.setProperty(i, "currentDefaultName", src.currentDefaultName)
      filteredEntriesModel.setProperty(i, "defaultSource", src.defaultSource)
      filteredEntriesModel.setProperty(i, "selectedDesktop", src.selectedDesktop)
      filteredEntriesModel.setProperty(i, "selectionDirty", src.selectionDirty)
      filteredEntriesModel.setProperty(i, "applying", src.applying)
      filteredEntriesModel.setProperty(i, "applyError", src.applyError)
      rebuildCommonGroups()
      return
    }

    rebuildCommonGroups()
  }

  function hasPendingCommonChanges() {
    for (var i = 0; i < entriesModel.count; i++) {
      var row = entriesModel.get(i)
      if (commonMimeTypes.indexOf(row.mimeType) !== -1 && row.selectionDirty) {
        return true
      }
    }
    return false
  }

  function handlerNameFor(index, desktopId) {
    var row = entriesModel.get(index)
    var handlers = row.handlers || []
    for (var i = 0; i < handlers.length; i++) {
      if (handlers[i].key === desktopId) {
        return handlers[i].name
      }
    }
    return desktopId
  }

  function applyDefault(sourceIndex) {
    if (applying || sourceIndex < 0 || sourceIndex >= entriesModel.count) return

    var row = entriesModel.get(sourceIndex)
    var selectedDesktop = row.selectedDesktop || ""
    if (!selectedDesktop) return

    pendingApplyIndex = sourceIndex
    applying = true
    statusMessage = ""

    entriesModel.setProperty(sourceIndex, "applyError", "")
    entriesModel.setProperty(sourceIndex, "applying", true)
    syncFilteredRowFromSource(sourceIndex)

    setProcess.command = [
      "python3",
      backendPath,
      "set-default",
      "--mime",
      row.mimeType,
      "--desktop",
      selectedDesktop
    ]
    setProcess.running = true
  }

  function startBatchApply() {
    if (applying || batchApplying) return
    var q = []
    for (var i = 0; i < entriesModel.count; i++) {
      var row = entriesModel.get(i)
      if (commonMimeTypes.indexOf(row.mimeType) !== -1 && row.selectionDirty) {
        q.push(i)
      }
    }
    if (q.length === 0) return
    batchApplying = true
    var first = q.shift()
    applyQueue = q
    applyDefault(first)
  }

  onPluginApiChanged: {
    updateBackendPath()
    if (backendPath !== "") {
      refreshList()
    }
  }

  Component.onCompleted: {
    updateBackendPath()
    if (backendPath !== "") {
      refreshList()
    }
  }

  onCommonGroupDefinitionsChanged: {
    if (entriesModel.count > 0) {
      rebuildGroupTabs()
      rebuildFilteredEntries()
    }
  }

  Process {
    id: scanProcess
    running: false
    command: []

    stdout: StdioCollector {
      id: scanStdout
    }

    stderr: StdioCollector {
      id: scanStderr
    }

    onExited: (exitCode) => {
      root.loading = false

      if (exitCode !== 0) {
        root.statusMessage = scanStderr.text.trim() || "Failed to scan MIME handlers. Ensure python3 is installed and available in PATH."
        return
      }

      try {
        var payload = JSON.parse(scanStdout.text)
        if (!payload.ok) {
          root.statusMessage = payload.error || "Scan failed."
          return
        }

        root.entriesModel.clear()
        root.filteredEntriesModel.clear()

        var rows = payload.entries || []
        for (var i = 0; i < rows.length; i++) {
          var row = rows[i]
          var handlers = row.handlers || []
          var selectedDesktop = row.currentDefault || (handlers.length > 0 ? handlers[0].key : "")

          root.entriesModel.append({
            mimeType: row.mimeType || "",
            handlers: handlers,
            currentDefault: row.currentDefault || "",
            currentDefaultName: row.currentDefaultName || "",
            defaultSource: row.defaultSource || "",
            selectedDesktop: selectedDesktop,
            selectionDirty: false,
            applying: false,
            applyError: ""
          })
        }

        root.rebuildGroupTabs()
        root.rebuildFilteredEntries()

        if (root.filteredEntriesModel.count === 0) {
          root.statusMessage = "No MIME handlers were found from installed desktop files."
        }
      } catch (e) {
        root.statusMessage = "Failed to parse scan result: " + e
      }
    }
  }

  Process {
    id: setProcess
    running: false
    command: []

    stdout: StdioCollector {
      id: setStdout
    }

    stderr: StdioCollector {
      id: setStderr
    }

    onExited: (exitCode) => {
      var index = root.pendingApplyIndex
      root.pendingApplyIndex = -1
      root.applying = false

      if (index >= 0 && index < root.entriesModel.count) {
        root.entriesModel.setProperty(index, "applying", false)
        root.syncFilteredRowFromSource(index)
      }

      if (exitCode !== 0) {
        var message = setStderr.text.trim() || "Failed to save default application. Ensure python3 is installed and available in PATH."
        root.statusMessage = message
        if (index >= 0 && index < root.entriesModel.count) {
          root.entriesModel.setProperty(index, "applyError", message)
          root.syncFilteredRowFromSource(index)
        }
        root.batchApplying = false
        root.applyQueue = []
        return
      }

      try {
        var payload = JSON.parse(setStdout.text)
        if (!payload.ok) {
          var error = payload.error || "Failed to save default application."
          root.statusMessage = error
          if (index >= 0 && index < root.entriesModel.count) {
            root.entriesModel.setProperty(index, "applyError", error)
            root.syncFilteredRowFromSource(index)
          }
          root.batchApplying = false
          root.applyQueue = []
          return
        }

        if (index >= 0 && index < root.entriesModel.count) {
          var selected = root.entriesModel.get(index).selectedDesktop || ""
          root.entriesModel.setProperty(index, "currentDefault", selected)
          root.entriesModel.setProperty(index, "currentDefaultName", root.handlerNameFor(index, selected))
          root.entriesModel.setProperty(index, "defaultSource", payload.file || "")
          root.entriesModel.setProperty(index, "selectionDirty", false)
          root.entriesModel.setProperty(index, "applyError", "")
          root.syncFilteredRowFromSource(index)
        }

        root.statusMessage = "Updated default for " + (payload.mimeType || "selected MIME type") + "."
      } catch (e) {
        root.statusMessage = "Default updated, but response parsing failed: " + e
      }

      if (root.applyQueue.length > 0) {
        var q = root.applyQueue.slice()
        var next = q.shift()
        root.applyQueue = q
        root.applyDefault(next)
      } else {
        root.batchApplying = false
      }
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true

        NText {
          text: pluginApi?.tr("panel.title") || "MimeApp GUI"
          pointSize: Style.fontSizeL
          font.weight: Font.DemiBold
          color: Color.mOnSurface
        }
      }

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("panel.subtitle") || "Select a default application for each MIME type. Changes are written to ~/.config/mimeapps.list."
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.marginM

        Rectangle {
          Layout.preferredWidth: 220 * Style.uiScaleRatio
          Layout.fillHeight: true
          radius: Style.radiusM
          color: Color.mSurfaceVariant
          visible: root.groupTabs.length > 1

          ScrollView {
            anchors.fill: parent
            anchors.margins: Style.marginS
            clip: true

            ListView {
              id: groupListView
              model: root.groupTabs
              spacing: Style.marginS
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                required property var modelData
                required property int index

                width: groupListView.width
                radius: Style.radiusS
                color: index === root.selectedGroupIndex ? Color.mPrimary : Color.mSurface
                implicitHeight: groupText.implicitHeight + (Style.marginS * 2)

                NText {
                  id: groupText
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  text: modelData.name + " (" + modelData.count + ")"
                  color: index === root.selectedGroupIndex ? Color.mOnPrimary : Color.mOnSurface
                  pointSize: Style.fontSizeS
                  font.weight: index === root.selectedGroupIndex ? Font.Medium : Font.Normal
                  wrapMode: Text.WordWrap
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedGroupIndex = index
                    root.rebuildFilteredEntries()
                  }
                }
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.marginM

          NText {
            Layout.fillWidth: true
            visible: root.loading
            text: pluginApi?.tr("panel.loading") || "Scanning desktop entries..."
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }

          NText {
            Layout.fillWidth: true
            visible: root.statusMessage !== ""
            text: root.statusMessage
            pointSize: Style.fontSizeS
            color: root.statusMessage.toLowerCase().indexOf("failed") !== -1 ? Color.mError : Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
          }

          StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.selectedGroupKey() === "common" ? 1 : 0

            // ── Card view (all non-common groups) ──────────────────────────
            ScrollView {
              clip: true

              ListView {
                id: listView
                model: root.filteredEntriesModel
                spacing: Style.marginS
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  required property int index
                  required property int sourceIndex
                  required property string mimeType
                  required property var handlers
                  required property string currentDefault
                  required property string currentDefaultName
                  required property string defaultSource
                  required property string selectedDesktop
                  required property bool selectionDirty
                  required property bool applying
                  required property string applyError

                  width: listView.width
                  color: Color.mSurfaceVariant
                  radius: Style.radiusM
                  implicitHeight: cardLayout.implicitHeight + (Style.marginM * 2)

                  ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    NText {
                      Layout.fillWidth: true
                      text: mimeType
                      pointSize: Style.fontSizeM
                      font.weight: Font.Medium
                      color: Color.mOnSurface
                      wrapMode: Text.WordWrap
                    }

                    NText {
                      Layout.fillWidth: true
                      text: "Current: " + (currentDefaultName || currentDefault || "(none)")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      wrapMode: Text.WordWrap
                    }

                    NText {
                      Layout.fillWidth: true
                      text: "Source: " + (defaultSource || "(not configured)")
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      wrapMode: Text.WordWrap
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginS

                      NComboBox {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.handler.label") || "Handler"
                        model: handlers
                        currentKey: selectedDesktop
                        enabled: !applying && !root.loading && !root.applying
                        onSelected: key => {
                          root.entriesModel.setProperty(sourceIndex, "selectedDesktop", key)
                          root.filteredEntriesModel.setProperty(index, "selectedDesktop", key)
                          root.entriesModel.setProperty(sourceIndex, "selectionDirty", key !== root.entriesModel.get(sourceIndex).currentDefault)
                          root.entriesModel.setProperty(sourceIndex, "applyError", "")
                          root.syncFilteredRowFromSource(sourceIndex)
                        }
                      }

                      NButton {
                        text: applying ? (pluginApi?.tr("panel.apply.saving") || "Saving...") : (pluginApi?.tr("panel.apply.button") || "Apply")
                        icon: "check"
                        enabled: !applying && !root.loading && !root.applying && selectedDesktop !== "" && selectionDirty
                        onClicked: root.applyDefault(sourceIndex)
                      }
                    }

                    NText {
                      Layout.fillWidth: true
                      visible: applyError !== ""
                      text: applyError
                      pointSize: Style.fontSizeS
                      color: Color.mError
                      wrapMode: Text.WordWrap
                    }
                  }
                }
              }
            }

            // ── Common grouped form view ───────────────────────────────────
            ColumnLayout {
              spacing: Style.marginM

              ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                  id: commonListView
                  model: root.commonGroupsModel
                  spacing: Style.marginS
                  boundsBehavior: Flickable.StopAtBounds

                  section.property: "friendlyCategory"
                  section.criteria: ViewSection.FullString
                  section.delegate: Item {
                    width: commonListView.width
                    height: sectionLabel.implicitHeight + (Style.marginL * 2)

                    NText {
                      id: sectionLabel
                      anchors.centerIn: parent
                      text: section
                      pointSize: Style.fontSizeM
                      font.weight: Font.DemiBold
                      color: Color.mOnSurface
                    }
                  }

                  delegate: Rectangle {
                    required property int index
                    required property var sourceIndexes
                    required property var mimeTypes
                    required property string selectedDesktop
                    required property bool selectionDirty
                    required property bool applying
                    required property string friendlyLabel
                    required property string applyError

                    width: commonListView.width
                    height: innerColumn.implicitHeight + Style.marginS
                    color: "transparent"

                    ColumnLayout {
                      id: innerColumn
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.marginXS

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NText {
                          Layout.preferredWidth: 180 * Style.uiScaleRatio
                          text: friendlyLabel + ":"
                          horizontalAlignment: Text.AlignRight
                          color: Color.mOnSurfaceVariant
                          pointSize: Style.fontSizeS
                        }

                        NComboBox {
                          id: commonCombo
                          Layout.fillWidth: true
                          model: root.handlersForCommonGroup(sourceIndexes)
                          currentKey: selectedDesktop
                          enabled: !applying && !root.loading && !root.applying && !root.batchApplying
                          onSelected: key => {
                            root.setCommonGroupSelection(sourceIndexes, key)
                          }
                        }
                      }

                      NText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 180 * Style.uiScaleRatio + Style.marginM
                        visible: applyError !== ""
                        text: applyError
                        pointSize: Style.fontSizeS
                        color: Color.mError
                        wrapMode: Text.WordWrap
                      }
                    }
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                NButton {
                  text: root.batchApplying ? (pluginApi?.tr("panel.apply.saving") || "Saving...") : (pluginApi?.tr("panel.apply.button") || "Apply")
                  icon: "check"
                  enabled: !root.loading && !root.applying && !root.batchApplying && root.hasPendingCommonChanges()
                  onClicked: root.startBatchApply()
                }
              }
            }
          }
        }
      }
    }
  }
}
