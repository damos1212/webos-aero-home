// "Looking glass" app tile: clear glass that refracts the live scene behind it,
// part-filled with the app's colour as a living liquid (waving surface,
// meniscus, swirls, rising bubbles, slosh when you move). Two passes:
//   back  : refraction + liquid      (behind the icon)
//   front : rim, gloss, glass streak (over the icon, so it sits inside)
import QtQuick 2.12
import QtGraphicalEffects 1.0

Item {
    id: card
    property var app
    property bool focused: false
    property bool pressed: false
    property var backdrop                 // the Ocean item (layer.enabled -> texture)
    property point origin: Qt.point(0, 0) // card's untransformed top-left in screen px
    property int introDelay: 0
    property int introSeq: 0
    property real introProgress: 0
    property real fxTime: 0              // shared clock from main (seconds)
    property real kickDir: 0             // -1 left, +1 right
    property real seed: introDelay * 0.031 + 0.7
    // per-tile slosh: a heavy kick when this tile gets selected; on deselection the
    // running slosh simply keeps playing out and decays on its own
    property real lkT: -100
    property real lkD: 0
    property real lkA: 0
    onFocusedChanged: if (focused) { lkT = fxTime; lkD = kickDir; lkA = 1.0 }
    property real calmAmt: focused ? 1 : 0          // eases slowly so motion winds down gently
    Behavior on calmAmt { NumberAnimation { duration: 1400; easing.type: Easing.InOutSine } }

    width: 236; height: 236

    onIntroSeqChanged: introAnim.restart()
    SequentialAnimation {
        id: introAnim
        PropertyAction { target: card; property: "introProgress"; value: 0 }
        PauseAnimation { duration: card.introDelay }
        NumberAnimation { target: card; property: "introProgress"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }

    property real focusAmt: focused ? 1 : 0
    Behavior on focusAmt { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    property real lift: (1 - introProgress) * 70 + (focused ? -16 : 0)
    Behavior on lift { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    // gentle bobbing, like it is floating on the water
    property real bob: 0
    SequentialAnimation on bob {
        loops: Animation.Infinite
        NumberAnimation { to: 5;  duration: 2200 + card.introDelay * 7; easing.type: Easing.InOutSine }
        NumberAnimation { to: -5; duration: 2200 + card.introDelay * 7; easing.type: Easing.InOutSine }
    }

    scale: (pressed ? 1.22 : (focused ? 1.16 : 1.0)) * (0.85 + 0.15 * introProgress)
    Behavior on scale { SpringAnimation { spring: 4.0; damping: 0.30; epsilon: 0.002 } }
    opacity: Math.min(1, introProgress * 1.4)
    transform: Translate { y: card.lift + card.bob }

    // contact shadow on the sand: cancels the tile's float so it stays on the ground,
    // and shrinks/softens/fades as the tile rises, tightens/darkens as it comes down
    Item {
        id: groundShadow
        property real h: Math.max(0, 6 - (card.lift + card.bob))      // px above the sand
        width: parent.width; height: 50
        y: parent.height + 4 - (card.lift + card.bob)
        opacity: Math.min(1, card.introProgress * 1.5)
        RadialGradient {                    // the original soft, blended shadow, now scaling with height
            anchors.centerIn: parent
            width: 236; height: 44
            scale: 1.0 + groundShadow.h * 0.006
            opacity: Math.max(0.18, 0.46 - groundShadow.h * 0.006)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.30, 0.20, 0.05, 0.75) }
                GradientStop { position: 0.5; color: "transparent" }
            }
        }
    }

    // soft cyan/white halo under the glass
    RectangularGlow {
        anchors.fill: glass
        glowRadius: 30
        spread: 0.15
        cornerRadius: 46 + glowRadius
        color: Qt.rgba(0.75, 0.95, 1.0, 1.0)
        opacity: 0.10 + 0.45 * card.focusAmt
    }

    ShaderEffect {
        id: glass
        anchors.fill: parent
        property var src: card.backdrop
        // where this glass sits on screen (normalised), so it samples what's behind it
        property point center: Qt.point((card.origin.x + card.width / 2) / 1920,
                                        (card.origin.y + card.height / 2 + card.lift + card.bob) / 1080)
        property point halfSize: Qt.point(card.width * card.scale / 2 / 1920, card.height * card.scale / 2 / 1080)
        property real focusK: card.focusAmt
        property color accent: card.app.accent
        property real tm: card.fxTime
        property real lkT: card.lkT
        property real lkD: card.lkD
        property real lkA: card.lkA
        property real bobv: card.bob / 5.0
        property real calmK: card.calmAmt
        property real seed: card.seed

        fragmentShader: "
            precision mediump float;
            uniform lowp float qt_Opacity;
            uniform sampler2D src;
            uniform vec2 center;
            uniform vec2 halfSize;
            uniform float focusK;
            uniform lowp vec4 accent;
            uniform float tm;
            uniform float lkT;
            uniform float lkD;
            uniform float lkA;
            uniform float bobv;
            uniform float calmK;
            uniform float seed;
            varying vec2 qt_TexCoord0;

            float sdRoundBox(vec2 p, vec2 b, float r) {
                vec2 q = abs(p) - b + r;
                return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
            }
            float hash(float n) { return fract(sin(n) * 43758.5453); }

            void main() {
                vec2 p = qt_TexCoord0 * 2.0 - 1.0;            // -1..1, y down
                float d = sdRoundBox(p, vec2(1.0), 0.40);
                float inside = 1.0 - smoothstep(-0.015, 0.015, d);
                if (inside <= 0.0) { gl_FragColor = vec4(0.0); return; }

                // clear glass: gentle magnification, strong bend at the rim, slight dispersion
                float edge = smoothstep(-0.45, 0.0, d);
                vec2 suv = center + p * (0.80 + 0.40 * edge * edge) * halfSize;
                float ca = 0.006 * edge;
                vec3 col;
                col.r = texture2D(src, suv + p * ca).r;
                col.g = texture2D(src, suv).g;
                col.b = texture2D(src, suv - p * ca).b;
                col = col * 1.04 + 0.03;

                // liquid: level rises when focused; surface waves + slosh after a move
                // damped sloshing modes after a selection: tilt, centre bulge, heave
                float dt = tm - lkT; if (dt < 0.0) dt = 100.0;
                float env = exp(-dt * 1.1);
                float slosh = lkD * lkA * env * sin(dt * 4.6) * 0.42 * p.x
                            + lkA * env * cos(dt * 7.3) * 0.10 * (p.x * p.x - 0.33)
                            - lkA * exp(-dt * 1.8) * sin(dt * 6.0) * 0.04;
                float level = -0.56 - 0.04 * focusK;                     // ~80% full
                float calm = 0.35 + 0.65 * calmK;                         // unfocused gentle, focused livelier
                // layered waves at uneven, slow speeds -> organic, never visibly repeating
                float surf = level + calm * (0.030 * sin(p.x * 2.3 + tm * 0.55 + seed)
                                           + 0.018 * sin(p.x * 4.1 - tm * 0.37 + seed * 1.7)
                                           + 0.010 * sin(p.x * 7.3 + tm * 0.83 + seed * 0.6))
                           + slosh + 0.015 * bobv;                       // liquid lags the bobbing glass
                float liq = smoothstep(surf - 0.012, surf + 0.012, p.y);
                if (liq > 0.0) {
                    float depth = clamp((p.y - surf) / (1.0 - surf), 0.0, 1.0);
                    vec2 wob = vec2(sin(p.y * 4.3 + tm * 0.47 + seed), cos(p.x * 3.7 - tm * 0.39 + seed)) * 0.05 * calm;
                    vec3 lbg = texture2D(src, center + (p * 0.55 + wob) * halfSize).rgb;
                    vec3 a = accent.rgb;
                    float al = dot(a, vec3(0.299, 0.587, 0.114));
                    vec3 av = clamp(mix(vec3(al), a, 1.55) * 1.04, 0.0, 1.0);          // extra-saturated app colour
                    vec3 lc = mix(mix(av, vec3(1.0), 0.12), av * 0.78, depth);
                    // slow swirling flow
                    vec2 fp = p + 0.35 * vec2(sin(p.y * 2.1 + tm * 0.23 + seed), sin(p.x * 1.7 - tm * 0.19 + seed * 1.3));   // domain warp
                    float sw = sin(fp.x * 3.4 + sin(fp.y * 2.6 + tm * 0.31 + seed) * 1.8 + tm * 0.21) * sin(fp.y * 4.2 - tm * 0.27 + seed);
                    lc += (av * smoothstep(0.3, 1.0, sw) * 0.30 + vec3(1.0) * smoothstep(0.80, 1.0, sw) * 0.12) * calm;
                    vec3 lcol = mix(lbg * mix(vec3(1.0), av, 0.78) * 1.17, lc, 0.59);  // vibrant but see-through
                    // caustic shimmer toward the bottom
                    float cs = sin(fp.x * 7.0 + tm * 0.7 + seed) * sin(fp.y * 6.0 - tm * 0.55);
                    lcol += vec3(1.0) * pow(max(cs, 0.0), 6.0) * 0.25 * depth * calm;
                    col = mix(col, lcol, liq * 0.85);
                    // bright meniscus line on the surface
                    col = mix(col, vec3(1.0), smoothstep(0.030, 0.0, abs(p.y - surf)) * 0.65);
                }
                gl_FragColor = vec4(col, 1.0) * inside * qt_Opacity;
            }"
    }

    // icon floats inside the glass, with a soft shadow
    Item {
        id: iconBox
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 6 + (2 + 3 * card.calmAmt) * Math.sin(card.fxTime * 0.8 + card.seed * 3.0)
        width: 124; height: 124
        Image {
            id: icon
            anchors.fill: parent
            sourceSize.width: 130; sourceSize.height: 130
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            visible: false
            source: card.app.icon
            onStatusChanged: if (status === Image.Error && card.app.fallback && source != card.app.fallback) source = card.app.fallback
        }
        Rectangle { id: iconMask; anchors.fill: parent; radius: 30; visible: false }
        OpacityMask { id: rounded; anchors.fill: parent; source: icon; maskSource: iconMask; visible: false }
        DropShadow {
            anchors.fill: parent
            source: rounded
            verticalOffset: 8; radius: 18; samples: 25
            color: Qt.rgba(0, 0.12, 0.35, 0.45)
            cached: true
        }
    }

    // front surface of the glass: rim, shine and a reflection streak, drawn over the icon
    ShaderEffect {
        anchors.fill: parent
        property real focusK: card.focusAmt
        fragmentShader: "
            precision mediump float;
            uniform lowp float qt_Opacity;
            uniform float focusK;
            varying vec2 qt_TexCoord0;
            float sdRoundBox(vec2 p, vec2 b, float r) {
                vec2 q = abs(p) - b + r;
                return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
            }
            void main() {
                vec2 p = qt_TexCoord0 * 2.0 - 1.0;
                float d = sdRoundBox(p, vec2(1.0), 0.40);
                float inside = 1.0 - smoothstep(-0.015, 0.015, d);
                float rim = smoothstep(-0.07, 0.0, d);
                float inner = smoothstep(-0.14, -0.10, d) * (1.0 - smoothstep(-0.10, -0.06, d));
                vec2 g = (p - vec2(0.0, -0.62)) * vec2(0.95, 2.6);
                float gloss = smoothstep(1.0, 0.15, length(g)) * smoothstep(0.1, -0.5, p.y);
                float streak = smoothstep(0.07, 0.0, abs(p.x + 0.66 + p.y * 0.18)) * smoothstep(0.5, -0.2, p.y);
                float a = clamp(rim * (0.55 + 0.35 * focusK) + inner * 0.20 + gloss * (0.40 + 0.12 * focusK)
                                + streak * 0.35, 0.0, 1.0);
                gl_FragColor = vec4(vec3(a), a) * inside * qt_Opacity;
            }"
    }
}
