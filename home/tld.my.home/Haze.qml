// Atmosphere drawn over the whole scene (incl. the palm): a luminous haze
// band at the horizon, slow drifting mist wisps and the sun's bloom.
// Low-res + premultiplied alpha, so it is soft and cheap. Only covers the top 75% of
// the screen (below that its alpha is < 0.5%), saving a quarter of the blend fill.
import QtQuick 2.12

Item {
    id: root
    property bool running: true
    property bool fixedClock: false
    layer.enabled: true
    // the parent sizes this item; it fills the top 75% only
    layer.textureSize: Qt.size(480, 203)
    layer.smooth: true

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property real t: 0
        NumberAnimation on t { running: root.running;   // vsync-locked clock
                                 from: 0; to: 628.3185; duration: 1036795; loops: Animation.Infinite }
        Timer { interval: 33; repeat: true; running: false   // replaced by the vsync clock above
                onTriggered: fx.t = (fx.t + 0.02) % 628.3185 }
        fragmentShader: "
            precision mediump float;
            uniform lowp float qt_Opacity;
            uniform float t;
            varying vec2 qt_TexCoord0;
            float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
            float noise(vec2 p) {
                vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
                return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
            }
            void main() {
                vec2 uv = qt_TexCoord0 * vec2(1.0, 0.75);   // item covers screen y 0..0.75
                float horizon = 0.43;
                float band = exp(-abs(uv.y - horizon) * 30.0) * 0.10;
                vec2 mp = vec2(uv.x * 2.2 + t * 0.10, uv.y * 6.0);
                float wisps = (noise(mp) * 0.65 + noise(mp * 2.3 - t * 0.05) * 0.35);
                wisps = smoothstep(0.45, 0.85, wisps) * exp(-abs(uv.y - 0.50) * 7.0) * 0.05;
                vec2 d = (uv - vec2(0.80, 0.20)) * vec2(1.7778, 1.0);
                float bloom = exp(-length(d) * 4.0) * 0.12;
                float a = clamp(band + wisps + bloom, 0.0, 0.25);
                vec3 c = mix(vec3(0.93, 0.97, 1.0), vec3(1.0, 0.99, 0.95), bloom / max(a, 0.001));
                // premultiplied: haze (alpha) + additive flare
                gl_FragColor = vec4(c * a, a) * qt_Opacity;
            }"
    }
}
