import QtQuick
import QtQuick.Layouts
import QtMultimedia
import qs.Commons
import "./components"

Item {
		id: root
    anchors.fill: parent

		property var pluginApi: null

		property real contentPreferredWidth: 400 * Style.uiScaleRatio
		property real contentPreferredHeight: 430 * Style.uiScaleRatio

		readonly property var geometryPlaceholder: root
		readonly property bool allowAttach: true


		ColumnLayout {
        anchors.fill:    parent
				anchors.margins: Style.marginXS
				spacing:         40

				StatBars {
						Layout.fillWidth: true
						pluginApi: root.pluginApi
				}


				Item {
						Layout.fillWidth: true
						Layout.preferredHeight: 350   

						Pet {
								pluginApi: root.pluginApi
								anchors.centerIn: parent
						}

						RowLayout {
								anchors.left: parent.left
								anchors.right: parent.right

								Item 	{ Layout.fillWidth: true }  
								Bed 	{ pluginApi: root.pluginApi }
								Item 	{ Layout.fillWidth: true }  
								Food 	{ pluginApi: root.pluginApi }
								Item 	{ Layout.fillWidth: true }  
								Soap 	{ }
								Item	{ Layout.fillWidth: true }  
						}
				}

				Ball {
						Layout.alignment: Qt.AlignHCenter
				}


				DebugButtons {
            pluginApi: root.pluginApi
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
