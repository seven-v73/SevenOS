import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1280
    height: 720
    color: "#080B13"

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property bool isFr: Qt.locale().name.toLowerCase().indexOf("fr") === 0
    property int sessionIndex: session.index
    property color accent: config.accent ? config.accent : "#8B7CFF"
    property color accent2: config.accent2 ? config.accent2 : "#5AB8FF"
    property string prismSource: config.prism ? config.prism : "assets/seven-prism.png"
    property string miniOsTitle: config.miniOsTitle ? config.miniOsTitle : "Equinox Balance"
    property string buildLabel: config.buildLabel ? config.buildLabel : "SevenOS · Hyprland"
    property string clockText: ""
    property string dateText: ""

    function tr(fr, en) {
        return isFr ? fr : en
    }

    function refreshClock() {
        var now = new Date()
        clockText = Qt.formatTime(now, Qt.locale(), "HH:mm")
        dateText = Qt.formatDate(now, Qt.locale(), isFr ? "dddd d MMMM" : "dddd, MMMM d")
    }

    Component.onCompleted: refreshClock()

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        onLoginSucceeded: {
            promptMessage.color = "#8EF0BC"
            promptMessage.text = tr("Ouverture de SevenOS…", "Opening SevenOS…")
            loginButton.enabled = false
            busy.running = true
            enterPulse.start()
        }
        onLoginFailed: {
            password.text = ""
            promptMessage.color = "#FF8490"
            promptMessage.text = tr("Mot de passe incorrect. Réessaie calmement.", "Incorrect password. Try again.")
            failShake.start()
        }
        onInformationMessage: {
            promptMessage.color = "#FFB86B"
            promptMessage.text = arguments[0]
        }
    }

    Timer {
        id: ambient
        interval: 32
        repeat: true
        running: true
        onTriggered: {
            glow.rotation = (glow.rotation + 0.08) % 360
            prism.rotation = Math.sin(Date.now() / 1800) * 1.5
            prism.opacity = 0.82 + (Math.sin(Date.now() / 1100) * 0.08)
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: refreshClock()
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#10192B" }
            GradientStop { position: 0.45; color: "#0A0E1A" }
            GradientStop { position: 1.0; color: "#151223" }
        }
    }

    Rectangle {
        id: horizon
        width: parent.width * 1.25
        height: parent.height * 0.46
        x: -parent.width * 0.12
        y: parent.height * 0.54
        radius: height / 2
        color: "#172C52"
        opacity: 0.30
        rotation: -4
    }

    Rectangle {
        width: parent.width * 1.1
        height: 2
        x: -parent.width * 0.05
        y: parent.height * 0.64
        color: accent2
        opacity: 0.20
        rotation: -2
    }

    Rectangle {
        width: parent.width * 0.62
        height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.705
        color: accent
        opacity: 0.18
    }

    Row {
        id: topBar
        x: 24
        y: 20
        width: parent.width - 48
        height: 42

        Text {
            width: parent.width / 2
            height: parent.height
            text: buildLabel
            color: "#DDE5F8"
            font.family: "SF Pro Text, Inter"
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Column {
            width: parent.width / 2
            spacing: 0
            Text {
                width: parent.width
                text: clockText
                color: "#F7F9FF"
                font.family: "SF Pro Display, Inter"
                font.pixelSize: 22
                horizontalAlignment: Text.AlignRight
            }
            Text {
                width: parent.width
                text: dateText
                color: "#9FAAC2"
                font.family: "SF Pro Text, Inter"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        id: glow
        width: Math.min(parent.width, parent.height) * 0.56
        height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.10
        color: "transparent"
        border.width: 1
        border.color: accent
        opacity: 0.22
    }

    Image {
        id: prism
        source: prismSource
        width: Math.min(parent.width, parent.height) * 0.18
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        id: brand
        anchors.horizontalCenter: parent.horizontalCenter
        y: prism.y + prism.height + 12
        text: "SevenOS"
        color: "#F6F8FF"
        font.family: "SF Pro Display, Inter"
        font.pixelSize: Math.max(26, Math.min(42, parent.width * 0.032))
        font.weight: Font.DemiBold
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: brand.y + brand.height + 6
        text: tr("Bon retour dans ton espace", "Welcome back to your space")
        color: "#AEB8D0"
        font.family: "SF Pro Text, Inter"
        font.pixelSize: Math.max(13, Math.min(17, parent.width * 0.013))
    }

    Rectangle {
        id: miniChip
        anchors.horizontalCenter: parent.horizontalCenter
        y: brand.y + brand.height + 34
        width: Math.min(300, Math.max(210, miniLabel.implicitWidth + 56))
        height: 30
        radius: 15
        color: "#24304A"
        opacity: 0.72
        border.width: 1
        border.color: accent

        Rectangle {
            width: 8
            height: 8
            radius: 4
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            color: accent2
            opacity: 0.95
        }

        Text {
            id: miniLabel
            anchors.centerIn: parent
            text: tr("Mini OS actif · ", "Active Mini OS · ") + miniOsTitle
            color: "#DDE6FF"
            font.family: "SF Pro Text, Inter"
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width - 42
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Rectangle {
        id: card
        width: Math.min(450, parent.width - 56)
        height: Math.min(456, parent.height - 126)
        radius: 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(parent.height - height - 54, parent.height * 0.44)
        color: "#D9111522"
        border.width: 1
        border.color: "#44FFFFFF"

        SequentialAnimation on opacity {
            running: true
            loops: 1
            NumberAnimation { from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
        }

        NumberAnimation {
            id: failShake
            target: card
            property: "x"
            from: card.x - 8
            to: card.x
            duration: 170
            easing.type: Easing.OutBack
        }

        SequentialAnimation {
            id: enterPulse
            NumberAnimation { target: card; property: "scale"; to: 0.985; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 12

            Row {
                width: parent.width
                height: 46
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 15
                    color: "#202741"
                    border.width: 1
                    border.color: accent
                    Image {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: prismSource
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Column {
                    width: parent.width - 56
                    spacing: 2
                    Text {
                        width: parent.width
                        text: tr("Connexion SevenOS", "SevenOS Sign In")
                        color: "#F7F9FF"
                        font.family: "SF Pro Display, Inter"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: tr("Hyprland · Mini OS prêt", "Hyprland · Mini OS ready")
                        color: "#9EA9C1"
                        font.family: "SF Pro Text, Inter"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                width: parent.width
                height: 14
                text: tr("Utilisateur", "User")
                color: "#7F8AA3"
                font.family: "SF Pro Text, Inter"
                font.pixelSize: 11
            }

            TextBox {
                id: name
                width: parent.width
                height: 42
                text: userModel.lastUser
                font.pixelSize: 14
                color: "#141B2D"
                textColor: "#F4F7FF"
                borderColor: "#34415F"
                focusColor: accent2
                hoverColor: accent
                radius: 15
                KeyNavigation.tab: password
                KeyNavigation.backtab: powerButton
                Keys.onPressed: {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(name.text, password.text, sessionIndex)
                        event.accepted = true
                    }
                }
            }

            Text {
                width: parent.width
                height: 14
                text: tr("Mot de passe", "Password")
                color: "#7F8AA3"
                font.family: "SF Pro Text, Inter"
                font.pixelSize: 11
            }

            PasswordBox {
                id: password
                width: parent.width
                height: 42
                font.pixelSize: 14
                focus: true
                color: "#141B2D"
                textColor: "#F4F7FF"
                borderColor: "#34415F"
                focusColor: accent2
                hoverColor: accent
                radius: 15
                tooltipFG: "#F4F7FF"
                tooltipBG: "#1B2337"
                KeyNavigation.tab: loginButton
                KeyNavigation.backtab: name
                Keys.onPressed: {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(name.text, password.text, sessionIndex)
                        event.accepted = true
                    }
                }
            }

            Row {
                width: parent.width
                height: 38
                spacing: 10

                ComboBox {
                    id: session
                    width: (parent.width - 10) / 2
                    height: 36
                    model: sessionModel
                    index: sessionModel.lastIndex
                    font.pixelSize: 12
                    color: "#141B2D"
                    textColor: "#DCE6FF"
                    borderColor: "#34415F"
                    focusColor: accent2
                    hoverColor: accent
                    KeyNavigation.tab: layoutBox
                    KeyNavigation.backtab: password
                }

                LayoutBox {
                    id: layoutBox
                    width: (parent.width - 10) / 2
                    height: 36
                    font.pixelSize: 12
                    color: "#141B2D"
                    textColor: "#DCE6FF"
                    borderColor: "#34415F"
                    focusColor: accent2
                    hoverColor: accent
                    KeyNavigation.tab: loginButton
                    KeyNavigation.backtab: session
                }
            }

            Text {
                id: promptMessage
                width: parent.width
                height: 22
                text: tr("Entre ton mot de passe pour continuer.", "Enter your password to continue.")
                color: "#AEB8D0"
                font.family: "SF Pro Text, Inter"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 18
                color: "#182033"
                opacity: 0.76
                border.width: 1
                border.color: "#27344F"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        width: 18
                        height: parent.height
                        text: "⌘"
                        color: accent2
                        font.family: "SF Pro Text, Inter"
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width - 28
                        height: parent.height
                        text: tr("Entrée ouvre la session · Tab change de champ", "Enter signs in · Tab moves between fields")
                        color: "#9BA7C0"
                        font.family: "SF Pro Text, Inter"
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                width: parent.width
                height: 44
                spacing: 10

                Button {
                    id: loginButton
                    width: parent.width - 98
                    height: 42
                    text: tr("Ouvrir SevenOS", "Open SevenOS")
                    radius: 17
                    color: accent
                    activeColor: accent2
                    pressedColor: "#3048CC"
                    disabledColor: "#3C465C"
                    textColor: "#FFFFFF"
                    font.pixelSize: 13
                    onClicked: sddm.login(name.text, password.text, sessionIndex)
                    KeyNavigation.tab: powerButton
                    KeyNavigation.backtab: layoutBox
                }

                Button {
                    id: powerButton
                    width: 88
                    height: 42
                    text: tr("Arrêter", "Power")
                    radius: 17
                    color: "#222A3D"
                    activeColor: "#303A55"
                    pressedColor: "#111827"
                    textColor: "#E6ECFA"
                    font.pixelSize: 12
                    onClicked: sddm.powerOff()
                    KeyNavigation.tab: name
                    KeyNavigation.backtab: loginButton
                }
            }
        }
    }

    Rectangle {
        id: busy
        property bool running: false
        width: 160
        height: 3
        radius: 2
        y: card.y + card.height - 20
        color: accent2
        opacity: running ? 0.85 : 0.0
        NumberAnimation on x {
            running: busy.running
            loops: Animation.Infinite
            from: card.x + 40
            to: card.x + card.width - 200
            duration: 850
            easing.type: Easing.InOutCubic
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 10

        Button {
            width: 96
            height: 36
            text: tr("Redémarrer", "Restart")
            radius: 15
            color: "#20283C"
            activeColor: "#303A55"
            pressedColor: "#111827"
            textColor: "#E6ECFA"
            font.pixelSize: 12
            onClicked: sddm.reboot()
        }
        Button {
            width: 96
            height: 36
            text: tr("Veille", "Sleep")
            radius: 15
            color: "#20283C"
            activeColor: "#303A55"
            pressedColor: "#111827"
            textColor: "#E6ECFA"
            font.pixelSize: 12
            onClicked: sddm.suspend()
        }
    }

    Column {
        x: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        spacing: 6

        Text {
            text: tr("Prism prêt", "Prism ready")
            color: "#DDE5F8"
            font.family: "SF Pro Text, Inter"
            font.pixelSize: 13
        }
        Text {
            width: Math.min(360, root.width * 0.42)
            text: tr("Le bureau charge ton espace, tes profils et tes réglages SevenOS.", "The desktop loads your space, profiles and SevenOS settings.")
            color: "#8793AC"
            font.family: "SF Pro Text, Inter"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}
