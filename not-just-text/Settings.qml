import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editText: cfg.text ?? defaults.text ?? ""
    property bool editFortuneEnabled: cfg.fortuneEnabled ?? defaults.fortuneEnabled ?? false
    property bool editFortuneOffensive: cfg.fortuneOffensive ?? defaults.fortuneOffensive ?? false
    property bool editFortuneEqual: cfg.fortuneEqual ?? defaults.fortuneEqual ?? false
    property string editFortuneCategory: cfg.fortuneCategory ?? defaults.fortuneCategory ?? ""
    property bool editListEnabled: cfg.listEnabled ?? defaults.listEnabled ?? false
    property string editTextFile: cfg.textFile ?? defaults.textFile ?? ""

    spacing: Style.marginL

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.fortune.label")
        description: pluginApi?.tr("settings.fortune.desc")
        checked: root.editFortuneEnabled
        onToggled: checked => {
            root.editFortuneEnabled = checked;
            if (checked) root.editListEnabled = false;
        }
    }

    NToggle {
        Layout.fillWidth: true
        visible: !root.editFortuneEnabled
        label: pluginApi?.tr("settings.list.label")
        description: pluginApi?.tr("settings.list.desc")
        checked: root.editListEnabled
        onToggled: checked => root.editListEnabled = checked
    }

    NTextInput {
        Layout.fillWidth: true
        visible: root.editListEnabled && !root.editFortuneEnabled
        label: pluginApi?.tr("settings.textFile.label")
        description: pluginApi?.tr("settings.textFile.desc")
        placeholderText: "~/.config/noctalia/plugins/not-just-text/examples.txt"
        text: root.editTextFile
        onTextChanged: root.editTextFile = text
    }

    NTextInput {
        Layout.fillWidth: true
        visible: !root.editFortuneEnabled && !root.editListEnabled
        label: pluginApi?.tr("settings.text.label")
        description: pluginApi?.tr("settings.text.desc")
        text: root.editText
        onTextChanged: root.editText = text
        onAccepted: root.saveSettings()
    }

    NTextInput {
        Layout.fillWidth: true
        visible: root.editFortuneEnabled
        label: pluginApi?.tr("settings.fortuneCategory.label")
        description: pluginApi?.tr("settings.fortuneCategory.desc")
        placeholderText: "computers"
        text: root.editFortuneCategory
        onTextChanged: root.editFortuneCategory = text
    }

    NToggle {
        Layout.fillWidth: true
        visible: root.editFortuneEnabled
        label: pluginApi?.tr("settings.fortuneOffensive.label")
        description: pluginApi?.tr("settings.fortuneOffensive.desc")
        checked: root.editFortuneOffensive
        onToggled: checked => root.editFortuneOffensive = checked
    }

    NToggle {
        Layout.fillWidth: true
        visible: root.editFortuneEnabled
        label: pluginApi?.tr("settings.fortuneEqual.label")
        description: pluginApi?.tr("settings.fortuneEqual.desc")
        checked: root.editFortuneEqual
        onToggled: checked => root.editFortuneEqual = checked
    }

    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.text = root.editText;
        pluginApi.pluginSettings.fortuneEnabled = root.editFortuneEnabled;
        pluginApi.pluginSettings.fortuneOffensive = root.editFortuneOffensive;
        pluginApi.pluginSettings.fortuneEqual = root.editFortuneEqual;
        pluginApi.pluginSettings.fortuneCategory = root.editFortuneCategory;
        pluginApi.pluginSettings.listEnabled = root.editListEnabled;
        pluginApi.pluginSettings.textFile = root.editTextFile;
        pluginApi.saveSettings();
    }
}
