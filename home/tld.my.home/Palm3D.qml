// Low-poly 3D palm tree, built entirely in vertex shaders (Qt 5.12 on the TV
// has no Qt Quick 3D): each ShaderEffect gets a small GridMesh and the vertex
// shader turns grid coords into 3D geometry, lights it and projects it.
//   trunk : ringed, tapering, bent cylinder (front half)
//   fronds: V-folded ribbons that droop and sway, leaflets cut in the fragment shader
// Fronds are drawn back-to-front (no depth buffer in the scene graph).
import QtQuick 2.12

Item {
    id: palm
    property bool running: true
    property real t: 0
    property bool fixedClock: false
    NumberAnimation on t { running: palm.running;   // vsync-locked clock (60 fps sway)
                                 from: 0; to: 628.3185; duration: 628318; loops: Animation.Infinite }
    Timer { interval: 33; repeat: true; running: false   // replaced by the vsync clock above
            onTriggered: palm.t = (palm.t + 0.033) % 628.3185 }

    // camera / projection (screen pixels), shared by all parts
    property vector3d cam: Qt.vector3d(0.0, 3.5, -9.0)
    property real focal: 1100
    property point center: Qt.point(1820, 722)
    property vector3d light: Qt.vector3d(-0.55, 0.70, 0.45)
    property vector3d crown: Qt.vector3d(-1.7, 7.4, 0.6)

    readonly property string common: "
        uniform highp mat4 qt_Matrix;
        uniform highp float t;
        uniform highp vec3 cam;
        uniform highp float focal;
        uniform highp vec2 center;
        uniform highp vec3 light;
        uniform highp vec3 crown;
        attribute highp vec4 qt_Vertex;
        attribute highp vec2 qt_MultiTexCoord0;
        vec2 project(vec3 p) { vec3 d = p - cam; return center + vec2(d.x, -d.y) * focal / d.z; }
        vec3 sway(float v) { return vec3(0.14 * sin(t * 0.9) * v * v, 0.0, 0.05 * sin(t * 0.7) * v * v); }
    "

    // ---- trunk ----
    ShaderEffect {
        anchors.fill: parent
        mesh: GridMesh { resolution: Qt.size(7, 15) }
        blending: false                       // opaque bark
        property real t: palm.t
        property vector3d cam: palm.cam
        property real focal: palm.focal
        property point center: palm.center
        property vector3d light: palm.light
        property vector3d crown: palm.crown
        vertexShader: palm.common + "
            varying lowp float shade;
            varying highp float ring;
            void main() {
                float u = qt_MultiTexCoord0.x;
                float v = 1.0 - qt_MultiTexCoord0.y;          // 0 base .. 1 crown
                float row = floor(v * 15.0 + 0.5);
                vec3 c = vec3(crown.x * v * v, crown.y * v, crown.z * v * v) + sway(v);
                float th = (u - 0.5) * 3.4;                   // front-facing half (+ a bit)
                vec3 n = vec3(sin(th), 0.0, -cos(th));
                float r = 0.40 * (1.0 - 0.45 * v) * (1.0 + 0.08 * mod(row, 2.0));
                vec3 p = c + n * r;
                shade = 0.30 + 0.80 * max(dot(n, normalize(light)), 0.0);
                ring = mod(row, 2.0);
                gl_Position = qt_Matrix * vec4(project(p), 0.0, 1.0);
            }"
        fragmentShader: "
            uniform lowp float qt_Opacity;
            varying lowp float shade;
            varying highp float ring;
            void main() {
                lowp vec3 bark = mix(vec3(0.52, 0.34, 0.18), vec3(0.78, 0.56, 0.32), step(0.5, ring));   // warmer, brighter
                lowp vec3 col = bark * shade + vec3(0.02, 0.05, 0.10);   // a little sky bounce
                gl_FragColor = vec4(col, 1.0) * qt_Opacity;
            }"
    }

    // ---- coconuts (simple shaded discs at the crown) ----
    Repeater {
        model: [[-0.25, -0.05, -0.30], [0.18, -0.12, -0.32], [0.0, -0.28, -0.25]]
        delegate: Rectangle {
            property vector3d p: Qt.vector3d(palm.crown.x + modelData[0] + 0.14 * Math.sin(palm.t * 0.9),
                                             palm.crown.y + modelData[1], palm.crown.z + modelData[2])
            property real s: palm.focal / (p.z - palm.cam.z)
            width: 0.36 * s; height: width; radius: width / 2
            x: palm.center.x + (p.x - palm.cam.x) * s - width / 2
            y: palm.center.y - (p.y - palm.cam.y) * s - height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#7a5a2a" }
                GradientStop { position: 1.0; color: "#2e1f0e" }
            }
        }
    }

    // ---- fronds (sorted back to front) ----
    property var fronds: {
        var list = [], n = 11;
        for (var i = 0; i < n; i++) {
            var yaw = i / n * 2 * Math.PI + (i % 2 ? 0.18 : -0.12);
            list.push({ yaw: yaw, pitch: 0.38 + 0.22 * ((i * 7) % 3) / 2, len: 3.3 + 0.5 * ((i * 5) % 4) / 3,
                        droop: 0.55 + 0.25 * ((i * 3) % 4) / 3, width: 0.62, phase: i * 1.37 });
        }
        list.sort(function (a, b) { return Math.sin(b.yaw) - Math.sin(a.yaw) });   // far (+z) first
        return list;
    }

    Repeater {
        model: palm.fronds
        delegate: ShaderEffect {
            anchors.fill: parent
            mesh: GridMesh { resolution: Qt.size(2, 18) }
            blending: false                   // opaque leaves; gaps are cut with discard
            property real t: palm.t
            property vector3d cam: palm.cam
            property real focal: palm.focal
            property point center: palm.center
            property vector3d light: palm.light
            property vector3d crown: palm.crown
            property real yaw: modelData.yaw
            property real pitch: modelData.pitch
            property real len: modelData.len
            property real droop: modelData.droop
            property real fwidth: modelData.width
            property real phase: modelData.phase
            vertexShader: palm.common + "
                uniform highp float yaw;
                uniform highp float pitch;
                uniform highp float len;
                uniform highp float droop;
                uniform highp float fwidth;
                uniform highp float phase;
                varying highp vec2 leaf;
                varying lowp float shade;
                void main() {
                    float a = qt_MultiTexCoord0.x * 2.0 - 1.0;     // -1 .. 1 across the frond
                    float v = qt_MultiTexCoord0.y;                 // 0 at crown .. 1 at tip
                    float yw = yaw + 0.07 * sin(t * 1.1 + phase) * v;
                    float pt = pitch + 0.06 * sin(t * 1.6 + phase * 1.7) * v;
                    vec3 dir = vec3(cos(yw) * cos(pt), sin(pt), sin(yw) * cos(pt));
                    vec3 base = crown + sway(1.0);
                    vec3 rib = base + dir * len * v;
                    rib.y -= droop * v * v * len;
                    vec3 tg = normalize(dir * len + vec3(0.0, -2.0 * droop * v * len, 0.0));
                    vec3 side = normalize(cross(tg, vec3(0.0, 1.0, 0.0)));
                    vec3 up = normalize(cross(side, tg));
                    float w = fwidth * sin(3.14159 * clamp(v * 1.05, 0.0, 1.0)) + 0.03;
                    vec3 p = rib + side * a * w - up * abs(a) * w * 0.45;   // V-fold
                    vec3 n = normalize(up - side * sign(a) * 0.45);
                    shade = 0.25 + 0.85 * abs(dot(n, normalize(light)));
                    leaf = vec2(a, v);
                    gl_Position = qt_Matrix * vec4(project(p), 0.0, 1.0);
                }"
            fragmentShader: "
                uniform lowp float qt_Opacity;
                varying highp vec2 leaf;
                varying lowp float shade;
                void main() {
                    highp float ax = abs(leaf.x);
                    highp float k = fract(leaf.y * 34.0 - ax * 1.6);
                    if (ax > 0.07 && k > 0.60) discard;             // gaps between leaflets
                    lowp vec3 dark = vec3(0.04, 0.35, 0.15);
                    lowp vec3 lit = vec3(0.42, 0.85, 0.27);                // lush, saturated green
                    lowp vec3 col = mix(dark, lit, shade * 0.9);
                    col = mix(col, vec3(0.78, 0.76, 0.28), smoothstep(0.75, 1.0, leaf.y) * 0.35);  // sun-bleached tips
                    gl_FragColor = vec4(col, 1.0) * qt_Opacity;
                }"
        }
    }
}
