import QtQuick 2.15

Item {
    id: root
    width: 980
    height: 660

    function onActivate() {
        pulse.running = true
    }

    function onLeave() {
        pulse.running = false
    }

    Rectangle {
        anchors.fill: parent
        color: "#0B1020"
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.32
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#253B76" }
            GradientStop { position: 0.45; color: "#151C34" }
            GradientStop { position: 1.0; color: "#0B1020" }
        }
    }

    Rectangle {
        id: halo
        width: 220
        height: 220
        radius: 110
        anchors.centerIn: parent
        color: "#6D5EF8"
        opacity: 0.18

        SequentialAnimation on opacity {
            id: pulse
            running: true
            loops: Animation.Infinite
            NumberAnimation { to: 0.08; duration: 1200 }
            NumberAnimation { to: 0.22; duration: 1200 }
        }
    }

    Rectangle {
        width: 620
        height: 360
        radius: 30
        anchors.centerIn: parent
        color: "#111827"
        border.color: "#6D5EF8"
        border.width: 1
        opacity: 0.96

        Image {
            id: prism
            source: "seven-prism.png"
            width: 110
            height: 110
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 42
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: prism.bottom
            anchors.topMargin: 26
            text: "SevenOS"
            color: "#F8FAFC"
            font.pixelSize: 44
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 226
            text: "Beyond the Desktop"
            color: "#9CCBFF"
            font.pixelSize: 18
        }

        Text {
            width: 480
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 270
            text: "Installing the SevenOS base, profiles, recovery tools and graphical experience."
            color: "#CBD5E1"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
