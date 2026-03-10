import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property var commonGroups: []

  implicitWidth: 760 * Style.uiScaleRatio
  spacing: Style.marginM

  function cloneCommonGroups(groups) {
    var source = groups || []
    var cloned = []
    for (var i = 0; i < source.length; i++) {
      var item = source[i] || ({})
      cloned.push({
        key: item.key || ("group-" + i),
        label: item.label || ("Group " + (i + 1)),
        category: item.category || "Other",
        categoryOrder: item.categoryOrder ?? i,
        mimeTypes: (item.mimeTypes || []).slice()
      })
    }
    return cloned
  }

  function parseMimeTypes(text) {
    var parts = String(text || "").split(/[\n,]/)
    var seen = {}
    var result = []
    for (var i = 0; i < parts.length; i++) {
      var mimeType = String(parts[i] || "").trim()
      if (!mimeType || seen[mimeType]) continue
      seen[mimeType] = true
      result.push(mimeType)
    }
    return result
  }

  function mimeTypesTextFor(index) {
    if (index < 0 || index >= commonGroups.length) return ""
    return (commonGroups[index].mimeTypes || []).join(", ")
  }

  function reloadSettings() {
    var savedGroups = pluginApi?.pluginSettings?.commonGroups
    var fallbackGroups = defaults.commonGroups || []
    commonGroups = cloneCommonGroups(savedGroups ?? fallbackGroups)
  }

  function updateGroupMimeTypes(index, text) {
    if (index < 0 || index >= commonGroups.length) return
    var groups = cloneCommonGroups(commonGroups)
    groups[index].mimeTypes = parseMimeTypes(text)
    commonGroups = groups
  }

  function resetCommonGroups() {
    commonGroups = cloneCommonGroups(defaults.commonGroups || [])
    saveSettings()
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.commonGroups = cloneCommonGroups(commonGroups)
    pluginApi.saveSettings()
  }

  Component.onCompleted: reloadSettings()
  onPluginApiChanged: reloadSettings()

  ScrollView {
    Layout.fillWidth: true
    clip: true

    ColumnLayout {
      id: content
      width: root.width
      spacing: Style.marginL

      NText {
        Layout.fillWidth: true
        text: "MimeApp GUI Settings"
        pointSize: Style.fontSizeL
        font.weight: Font.DemiBold
        color: Color.mOnSurface
      }

      Rectangle {
        Layout.fillWidth: true
        radius: Style.radiusM
        color: Color.mSurfaceVariant
        implicitHeight: commonGroupsContent.implicitHeight + (Style.marginM * 2)

        ColumnLayout {
          id: commonGroupsContent
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true

            NText {
              text: "Common Tab Groups"
              pointSize: Style.fontSizeM
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            NButton {
              text: "Reset to defaults"
              icon: "refresh-cw"
              onClicked: root.resetCommonGroups()
            }
          }

          NText {
            Layout.fillWidth: true
            text: "Edit the MIME types that appear in each Common-tab group. Use commas to separate MIME types. If the same MIME type appears in multiple groups, the first group wins."
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.commonGroups.length

            delegate: Rectangle {
              required property int index

              Layout.fillWidth: true
              radius: Style.radiusS
              color: Color.mSurface
              implicitHeight: groupContent.implicitHeight + (Style.marginM * 2)

              ColumnLayout {
                id: groupContent
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                  Layout.fillWidth: true
                  text: root.commonGroups[index].label + " (" + root.commonGroups[index].category + ")"
                  pointSize: Style.fontSizeM
                  font.weight: Font.Medium
                  color: Color.mOnSurface
                }

                NTextInput {
                  Layout.fillWidth: true
                  label: "MIME types"
                  description: "Comma-separated MIME types shown in this group"
                  text: root.mimeTypesTextFor(index)
                  placeholderText: "example/type, x-scheme-handler/example"
                  onEditingFinished: {
                    root.updateGroupMimeTypes(index, text)
                    root.saveSettings()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
