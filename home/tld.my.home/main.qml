// Home: native QML home screen for the LG C1 (runs under LG's qml-runner).
// Frutiger Aero / Y2K "blue sky" look: live ocean + sky shader, looking-glass
// app tiles that refract the water, drifting bubbles, glossy pills.
import QtQuick 2.12
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0
import QtMultimedia 5.9
import Eos.Window 0.1
import WebOSServices 1.0

WebOSWindow {
    id: win
    width: 1920
    height: 1080
    visible: true
    color: "#000000"
    appId: "tld.my.home"
    title: "Home"

    readonly property string uiFont: "LG Smart UI"

    // ---- apps -------------------------------------------------------------
    readonly property string devApps: "file:///media/developer/apps/usr/palm/applications/"
    property var apps: [
        { id: "org.jellyfin.webos",      title: "Jellyfin", subtitle: "Your media library",
          icon: devApps + "org.jellyfin.webos/assets/icon-130.png", accent: "#8a5cf6" },
        { id: "youtube.leanback.v4",     title: "YouTube",  subtitle: "Ad-free",
          icon: devApps + "youtube.leanback.v4/117157680832032139_16977867_192x192.png",
          fallback: devApps + "youtube.leanback.v4/yt_lg_130x130.png", accent: "#ff3355" },
        { id: "twitch.adamffdev.v1",     title: "Twitch",   subtitle: "Ad-free",
          icon: devApps + "twitch.adamffdev.v1/largeIcon.png", accent: "#9b5cff" },
        { id: "com.aurora.gamestream",   title: "Aurora",   subtitle: "Game streaming",
          icon: devApps + "com.aurora.gamestream/icon_large.png", accent: "#3d8bff" },
        { id: "org.webosbrew.hbchannel", title: "Homebrew", subtitle: "Homebrew Channel",
          icon: devApps + "org.webosbrew.hbchannel/assets/icon130.png", accent: "#ff2a7a" }
    ]
    Component.onCompleted: {
        try { var x = new XMLHttpRequest(); x.open("GET", "file:///tmp/home-record", false); x.send(); rec = x.responseText.length > 0 } catch (e) { rec = false }
        selected = rec ? 1 : Math.max(0, Math.min(apps.length - 1, store.selected))
        try { var y = new XMLHttpRequest(); y.open("GET", "file:///tmp/home-fps", false); y.send(); showFps = y.responseText.length > 0 } catch (e2) { showFps = false }
        if (rec) { collectStage(); recording = true; demo.start() }
        if (!rec) { lifecycle.callService({ "appId": "tld.my.home", "subscribe": true }); lifeEvents.callService({ "subscribe": true }) }
        intro.restart()
        updateSound()
    }

    Settings { id: store; category: "home"; property int selected: 1 }
    property int selected: 1
    property bool warmTitles: true
    Timer { interval: 1200; running: true; onTriggered: win.warmTitles = false }
    // shared animation clock + slosh impulse for the glass tiles
    property real fxTime: 0
    property real kickTime: -100
    property real kickDir: 0
    // smooth 60 fps clock for the liquid tiles (animation driver, also deterministic when recording)
    NumberAnimation on fxTime { running: win.active || win.rec; from: 0; to: 628.3185; duration: 628318; loops: Animation.Infinite }

    // ---- record mode (for the trailer) --------------------------------------
    // Enabled when /tmp/home-record exists. Run with QML_FIXED_ANIMATION_STEP=1 so every
    // rendered frame advances exactly 1/60 s; every 2nd frame is saved -> smooth 30 fps.
    property bool rec: false
    property bool recording: false
    property int recFrame: 0
    property int recSaved: 0
    function pad5(n) { var s = "" + n; while (s.length < 5) s = "0" + s; return s }
    // record mode: save every animation step, named by its exact animation time in ms;
    // the trailer script then picks the nearest frame for each 1/30 s slot
    onFxTimeChanged: {
        if (!recording) return;
        var ms = Math.round(fxTime * 1000);
        if (ms <= recSaved) return;
        recSaved = ms;
        stage.grabToImage(function (r) { r.saveToFile("/tmp/rec/f" + win.pad7(ms) + ".jpg") });
    }
    function pad7(n) { var s = "" + n; while (s.length < 7) s = "0" + s; return s }
    // ---- debug FPS meter: shown when /tmp/home-fps exists (read at start) ----
    property bool showFps: false
    property int fpsFrames: 0
    property real fpsValue: 0
    property real fpsMin: 999
    onFrameSwapped: if (showFps) fpsFrames++
    Timer { interval: 1000; repeat: true; running: win.showFps
            onTriggered: { win.fpsValue = win.fpsFrames; if (win.fpsFrames > 0) win.fpsMin = Math.min(win.fpsMin, win.fpsFrames); win.fpsFrames = 0 } }
    Text { visible: win.showFps; z: 9999; x: 1700; y: 20; color: "yellow"; style: Text.Outline; styleColor: "black"
           font.pixelSize: 34; text: win.fpsValue + " fps (min " + (win.fpsMin === 999 ? "-" : win.fpsMin) + ")" }

    // in record mode every visual layer is moved into this item so it can be grabbed as one image
    Item { id: stage; width: 1920; height: 1080 }   // fixed size, so the grab is full-res even if the window is small
    function collectStage() {
        var kids = [];
        for (var i = 0; i < contentItem.children.length; i++) kids.push(contentItem.children[i]);
        for (var j = 0; j < kids.length; j++) if (kids[j] !== stage) kids[j].parent = stage;
    }
    function demoMove(dir) { kick(dir); selected = Math.max(0, Math.min(apps.length - 1, selected + dir)) }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: 4000 }  ScriptAction { script: win.demoMove(1) }     //  4.0 Twitch
        PauseAnimation { duration: 1300 }  ScriptAction { script: win.demoMove(1) }     //  5.3 Aurora
        PauseAnimation { duration: 1300 }  ScriptAction { script: win.demoMove(1) }     //  6.6 Homebrew
        PauseAnimation { duration: 1700 }  ScriptAction { script: win.demoMove(-1) }    //  8.3 Aurora
        PauseAnimation { duration: 900 }   ScriptAction { script: win.demoMove(-1) }    //  9.2 Twitch
        PauseAnimation { duration: 900 }   ScriptAction { script: win.demoMove(-1) }    // 10.1 YouTube
        PauseAnimation { duration: 900 }   ScriptAction { script: win.demoMove(-1) }    // 11.0 Jellyfin
        PauseAnimation { duration: 2000 }  ScriptAction { script: win.demoMove(1) }     // 13.0 YouTube
        PauseAnimation { duration: 2200 }  ScriptAction { script: leaving.restart() }   // 15.2 select YouTube
        PauseAnimation { duration: 1500 }  ScriptAction { script: win.recording = false }               // 16.7 end (video fades out)
    }
    function kick(dir) { kickDir = dir; kickTime = fxTime }
    onSelectedChanged: store.selected = selected
    readonly property var current: apps[selected]

    // ---- system calls ----------------------------------------------------
    Service { id: luna; appId: "tld.my.home" }
    // App lifecycle, the same way LG's own QML apps do it: register with the app manager
    // and, when HOME relaunches us while another app (e.g. YouTube) is in front,
    // show + raise our own window. Without this the system can leave it hidden.
    Service {
        id: lifecycle
        appId: "tld.my.home"
        service: "com.webos.applicationManager"
        method: "registerApp"
        onCallSuccess: if (response && response.event === "relaunch") win.bringToFront()
    }
    // the system hides our window behind other apps without telling QML, so mirror that:
    // mark the window hidden when we go to the background, show it again on relaunch
    Service {
        id: lifeEvents
        appId: "tld.my.home"
        service: "com.webos.applicationManager"
        method: "getAppLifeEvents"
        onCallSuccess: {
            if (!response || response.appId !== "tld.my.home") return;
            if (response.event === "background" || response.event === "stop") win.visible = false;
            else if (response.event === "foreground" || response.event === "launch" || response.event === "splash") win.bringToFront();
        }
    }
    function bringToFront() {
        if (visible) { visible = false; Qt.callLater(function () { win.visible = true; win.raise(); win.requestActivate() }) }
        else { visible = true; raise(); requestActivate() }
    }
    function launch(i) {
        luna.call("luna://com.webos.applicationManager/", "launch", JSON.stringify({ id: apps[i].id }))
    }

    // ---- world -------------------------------------------------------------
    Ocean {
        id: ocean
        anchors.fill: parent
        fixedClock: win.rec
        tint: win.current.accent
        running: win.active || win.rec
    }

    Palm3D {
        anchors.fill: parent
        fixedClock: win.rec
        running: win.active || win.rec
    }

    Haze {
        width: parent.width; height: parent.height * 0.75
        fixedClock: win.rec
        running: win.active || win.rec
    }

    // ---- ambient soundtrack: only while the home is on screen ----------
    Settings { id: soundPrefs; category: "sound"; property real volume: 0.55; property bool enabled: true }
    // Ambience: a seamless 2-minute loop held in memory and played as raw audio through
    // the TV's sound server (sample-accurate looping, no hardware decoder taken away
    // from YouTube/Netflix). Fades in while the home is visible, fades out when leaving.
    property real bgmLevel: 0
    Behavior on bgmLevel { NumberAnimation { duration: 900 } }
    SoundEffect {
        id: ambience
        source: "ambient.wav"
        loops: SoundEffect.Infinite
        volume: win.bgmLevel
        onStatusChanged: if (status === SoundEffect.Ready) win.updateSound()
    }
    QtObject {
        id: bgm
        function play() { if (ambience.status === SoundEffect.Ready && !ambience.playing) ambience.play() }
        function pause() { ambience.stop() }
        function stop() { ambience.stop() }
    }
    // safety net: if the stream ever stops while the home is showing, start it again
    Timer { interval: 3000; repeat: true; running: win.active && soundPrefs.enabled && !win.rec
            onTriggered: if (!ambience.playing) { bgm.play(); win.bgmLevel = soundPrefs.volume } }
    Timer { id: pauseLater; interval: 950; onTriggered: if (!win.active) bgm.pause() }

    // UI sounds: a pentatonic glass tick per tile, and a chime on open
    property var moveSfx: [sfx0, sfx1, sfx2, sfx3, sfx4]
    SoundEffect { id: sfx0; source: "sfx/move_0.wav"; volume: 0.55 }
    SoundEffect { id: sfx1; source: "sfx/move_1.wav"; volume: 0.55 }
    SoundEffect { id: sfx2; source: "sfx/move_2.wav"; volume: 0.55 }
    SoundEffect { id: sfx3; source: "sfx/move_3.wav"; volume: 0.55 }
    SoundEffect { id: sfx4; source: "sfx/move_4.wav"; volume: 0.55 }
    SoundEffect { id: sfxSelect; source: "sfx/select.wav"; volume: 0.65 }
    function tick() { if (soundPrefs.enabled) moveSfx[selected % moveSfx.length].play() }
    function updateSound() {
        if (win.active && soundPrefs.enabled && !win.rec) { pauseLater.stop(); bgm.play(); win.bgmLevel = soundPrefs.volume }
        else { win.bgmLevel = 0; pauseLater.restart() }
    }

    // slow anti burn-in drift of the foreground
    property real driftX: 0
    property real driftY: 0
    Behavior on driftX { NumberAnimation { duration: 6000; easing.type: Easing.InOutSine } }
    Behavior on driftY { NumberAnimation { duration: 6000; easing.type: Easing.InOutSine } }
    Timer { interval: 180000; running: true; repeat: true
            onTriggered: { win.driftX = Math.round(Math.random() * 16 - 8); win.driftY = Math.round(Math.random() * 12 - 6) } }

    Item {
        id: content
        width: parent.width; height: parent.height
        x: win.driftX; y: win.driftY

        // Clock pill + date, top left (the palm owns the right side)
        Row {
            anchors { top: parent.top; left: parent.left; topMargin: 64; leftMargin: 120 }
            spacing: 22
            GlossPill { id: clockPill; padH: 30
                        font.pixelSize: 44; font.weight: Font.Light; text: Qt.formatTime(new Date(), "HH:mm") }
            Text { id: date; anchors.verticalCenter: clockPill.verticalCenter
                   color: "#ffffff"; opacity: 0.9; font.family: win.uiFont; font.pixelSize: 22
                   style: Text.Raised; styleColor: Qt.rgba(0, 0.2, 0.5, 0.5)
                   text: Qt.formatDate(new Date(), "dddd d MMMM") }
            Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: { var n = new Date(); clockPill.text = Qt.formatTime(n, "HH:mm"); date.text = Qt.formatDate(n, "dddd d MMMM") } }
        }

        // Focused app name. Every title (text + gloss + soft shadow + pill) is built once
        // and cached; switching apps only crossfades/slides those cached images with
        // GPU transforms, so nothing is re-rendered or re-laid-out during the animation.
        Item {
            id: hero
            x: 120; y: 230
            width: 1200; height: 220
            Repeater {
                model: win.apps
                delegate: Item {
                    id: h
                    property bool shown: index === win.selected
                    width: 1200; height: 220
                    // clean handoff: the old title leaves first, then the new one comes in
                    // from the side you moved toward, so two titles never overlap
                    property real slideX: 0
                    opacity: 0
                    visible: opacity > 0.001
                    transform: Translate { x: h.slideX }
                    Component.onCompleted: opacity = shown ? 1 : 0.004      // 0.004: invisible pre-render
                    Connections { target: win; onWarmTitlesChanged: if (!win.warmTitles && !h.shown && !outAnim.running) h.opacity = 0 }
                    onShownChanged: { if (shown) { outAnim.stop(); inAnim.restart() } else { inAnim.stop(); outAnim.restart() } }
                    // Arrival: starts after only 70 ms with a soft-start fade (no visible overlap with
                    // the leaving title), glides in and settles gently. Interruptible: it always
                    // continues from the current position/opacity, so fast scrolling never goes blank.
                    SequentialAnimation {
                        id: inAnim
                        ScriptAction { script: if (h.opacity < 0.05) h.slideX = (win.kickDir < 0 ? -1 : 1) * 26 }
                        PauseAnimation { duration: h.opacity < 0.05 ? 70 : 0 }
                        ParallelAnimation {
                            NumberAnimation { target: h; property: "opacity"; to: 1; duration: 260
                                              easing.type: Easing.BezierSpline; easing.bezierCurve: [0.55, 0, 0.25, 1, 1, 1] }
                            NumberAnimation { target: h; property: "slideX"; to: 0; duration: 380
                                              easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] }
                        }
                    }
                    // Exit: opacity drops fast right away (ease-out), slight drift the other way
                    ParallelAnimation {
                        id: outAnim
                        NumberAnimation { target: h; property: "opacity"; to: 0; duration: 120
                                          easing.type: Easing.BezierSpline; easing.bezierCurve: [0.0, 0, 0.2, 1, 1, 1] }
                        NumberAnimation { target: h; property: "slideX"; to: (win.kickDir < 0 ? 1 : -1) * 12; duration: 140
                                          easing.type: Easing.BezierSpline; easing.bezierCurve: [0.0, 0, 0.2, 1, 1, 1] }
                    }
                    Item {
                        id: heroText
                        width: 1200; height: 150
                        Text { id: heroTitle; text: modelData.title; color: "#ffffff"; font.family: win.uiFont
                               font.weight: Font.Light; font.pixelSize: 128; font.letterSpacing: -3 }
                        LinearGradient {   // gloss band across the letters
                            anchors.fill: heroTitle
                            source: heroTitle
                            cached: true
                            start: Qt.point(0, 0); end: Qt.point(0, heroTitle.height)
                            gradient: Gradient {
                                GradientStop { position: 0.0;  color: "#ffffff" }
                                GradientStop { position: 0.52; color: "#ffffff" }
                                GradientStop { position: 0.56; color: "#d6f3ff" }
                                GradientStop { position: 1.0;  color: "#9fe2ff" }
                            }
                        }
                    }
                    DropShadow {
                        anchors.fill: heroText; source: heroText
                        verticalOffset: 6; radius: 22; samples: 31
                        color: Qt.rgba(0, 0.18, 0.5, 0.55)
                        cached: true
                    }
                    GlossPill {
                        anchors { top: heroText.bottom; topMargin: 6; left: parent.left; leftMargin: 8 }
                        text: modelData.subtitle
                        glow: modelData.accent
                        font.pixelSize: 26
                    }
                }
            }
        }

        // Looking-glass app tiles floating on the water
        Row {
            id: row
            anchors { left: parent.left; leftMargin: 120; top: parent.top; topMargin: 650 }
            spacing: 52
            Repeater {
                model: win.apps
                delegate: GlassCard {
                    app: modelData
                    backdrop: ocean
                    origin: Qt.point(row.x + x + content.x, row.y + content.y)
                    focused: index === win.selected
                    pressed: index === win.selected && leaving.running
                    introDelay: index * 70
                    introSeq: win.introSeq
                    fxTime: win.fxTime
                    kickDir: win.kickDir
                }
            }
        }
    }

    // ---- intro / leaving ---------------------------------------------------
    property int introSeq: 0
    NumberAnimation {
        id: intro
        target: content; property: "opacity"; from: 0; to: 1; duration: 300
        onStarted: win.introSeq++
    }
    SequentialAnimation {
        id: leaving
        PauseAnimation { duration: 70 }
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
    }
    // first start: full intro (tiles rise in). Coming back from an app: same screen,
    // just a quick soft fade so it feels like returning, not reopening.
    property bool firstShowDone: false
    NumberAnimation { id: welcomeBack; target: content; property: "opacity"; from: 0.35; to: 1; duration: 260; easing.type: Easing.OutCubic }
    onActiveChanged: {
        if (active) {
            leaving.stop();
            if (!firstShowDone) { firstShowDone = true; intro.restart() } else welcomeBack.restart();
        }
        updateSound()
    }
    Component.onDestruction: bgm.stop()

    // ---- remote --------------------------------------------------------
    Item {
        focus: true
        Keys.onPressed: {
            if (leaving.running) { event.accepted = true; return }
            if (event.key === Qt.Key_Left) {
                if (win.selected > 0) { win.kick(-1); win.selected--; win.tick() } event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (win.selected < win.apps.length - 1) { win.kick(1); win.selected++; win.tick() } event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                if (!event.isAutoRepeat) { if (soundPrefs.enabled) sfxSelect.play(); win.launch(win.selected); leaving.restart(); win.bgmLevel = 0 }
                event.accepted = true
            }
        }
    }
}
