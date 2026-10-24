// Glossy Y2K / Frutiger Aero pill.
import QtQuick 2.12

Rectangle {
    id: pill
    property alias text: label.text
    property alias font: label.font
    property color glow: "#7fd8ff"
    property real padH: 26
    height: label.implicitHeight + 18
    width: label.implicitWidth + padH * 2
    radius: height / 2
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.60) }
        GradientStop { position: 0.49; color: Qt.rgba(1, 1, 1, 0.20) }
        GradientStop { position: 0.51; color: Qt.rgba(pill.glow.r, pill.glow.g, pill.glow.b, 0.36) }
        GradientStop { position: 1.0; color: Qt.rgba(pill.glow.r, pill.glow.g, pill.glow.b, 0.66) }
    }
    border.width: 2
    border.color: Qt.rgba(1, 1, 1, 0.75)

    Text { // shadow
        x: label.x + 1; y: label.y + 2
        text: label.text; font: label.font
        color: Qt.rgba(0, 0.15, 0.4, 0.45)
    }
    Text {
        id: label
        anchors.centerIn: parent
        color: "#ffffff"
        font.family: "LG Smart UI"
        font.pixelSize: 26
    }
}
