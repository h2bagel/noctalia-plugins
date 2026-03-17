import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var cfg:      pluginApi?.pluginSettings                      || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string valueAnimationsFolder: cfg.animationsFolder ?? defaults.animationsFolder
    property string valueTargetFile:       cfg.targetFile       ?? defaults.targetFile
    property string valueIconColor:        cfg.iconColor        ?? defaults.iconColor ?? "none"

    spacing: Style.marginL

    Component.onCompleted: {
        Logger.d("AnimPicker", "Settings UI loaded")
    }

    ColumnLayout {
        spacing: Style.marginM
        Layout.fillWidth: true

        // Animations folder
        NTextInput {
            Layout.fillWidth: true
            label: "Animations folder"
            description: "Folder containing your .kdl preset files"
            placeholderText: "~/.config/niri/animations"
            text: root.valueAnimationsFolder
            onTextChanged: root.valueAnimationsFolder = text
        }

        // Target file
        NTextInput {
            Layout.fillWidth: true
            label: "Target KDL file"
            description: "File where the include line will be written"
            placeholderText: "~/.config/niri/animations.kdl"
            text: root.valueTargetFile
            onTextChanged: root.valueTargetFile = text
        }

        // Icon color
        NColorChoice {
            label: "Icon color"
            description: "Color of the bar widget icon"
            currentKey: root.valueIconColor
            onSelected: key => root.valueIconColor = key
        }
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("AnimPicker", "Cannot save settings: pluginApi is null")
            return
        }
        pluginApi.pluginSettings.animationsFolder = root.valueAnimationsFolder
        pluginApi.pluginSettings.targetFile       = root.valueTargetFile
        pluginApi.pluginSettings.iconColor        = root.valueIconColor
        pluginApi.saveSettings()
        Logger.d("AnimPicker", "Settings saved")
    }
}
