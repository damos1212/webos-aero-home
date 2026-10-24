// Sega-blue-sky tropical beach: sky + sun + clouds, a narrow sea with a
// turquoise lagoon, foam washing in and out, and warm sand in front shaded by
// swaying palm-leaf shadows (so the glass icons sit on a calm mid-tone).
// Rendered at 640x360 and scaled up; time stepped at 30 fps for the Mali-G51.
import QtQuick 2.12

Item {
    id: root
    property color tint: "#2aa8ff"
    property bool running: true
    property real fps: 60                 // full frame rate: smoother water and clouds
    property bool fixedClock: false
    property real vibrance: 0.6           // 0 = previous grade, 1 = punchier (saturation + soft contrast + lift)

    Behavior on tint { ColorAnimation { duration: 1200; easing.type: Easing.InOutQuad } }

    layer.enabled: true
    layer.textureSize: Qt.size(640, 360)
    layer.smooth: true

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property real t: 0
        property color tint: root.tint
        property real vib: root.vibrance
        NumberAnimation on t { running: root.running;   // vsync-locked clock
                                 from: 0; to: 628.3185; duration: 1047197; loops: Animation.Infinite }

        Timer {
            interval: Math.round(1000 / root.fps); repeat: true; running: false   // replaced by the vsync clock above
            // wrap so sin() arguments stay small (GPU precision)
            // 0.6x speed: everything drifts slowly, dreamlike
            onTriggered: fx.t = (fx.t + 0.6 * interval / 1000.0) % 628.3185
        }

        fragmentShader: "
            #ifdef GL_FRAGMENT_PRECISION_HIGH
            precision highp float;
            #else
            precision mediump float;
            #endif
            uniform lowp float qt_Opacity;
            uniform float t;
            uniform lowp vec4 tint;
            uniform lowp float vib;
            varying vec2 qt_TexCoord0;

            float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
            float noise(vec2 p) {
                vec2 i = floor(p), f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
            }
            float fbm(vec2 p) {
                float s = 0.0, a = 0.5;
                for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
                return s;
            }
            // gleaming glass future-city on the horizon: rgb = colour, a = coverage
            vec4 city(vec2 p, float hz) {
                float x = p.x;
                float up = hz - p.y;                               // height above the waterline
                if (up < 0.0 || up > 0.17 || x < 0.30 || x > 0.70) return vec4(0.0);
                float env = 0.25 + 0.75 * exp(-pow((x - 0.51) / 0.075, 2.0));
                float edge = smoothstep(0.30, 0.36, x) * (1.0 - smoothstep(0.64, 0.70, x));
                float cw = 1.0 / 110.0;                            // narrower lots = more towers
                float cell = floor(x / cw);
                float fx = fract(x / cw);
                float r = hash(vec2(cell, 3.0));
                float r2 = hash(vec2(cell, 9.0));
                float th = (0.008 + 0.125 * r * r) * env * edge;  // tower height
                float present = step(0.18, r2);
                // stepped setbacks: upper part of some towers is narrower
                float rel = up / max(th, 0.001);
                float halfw = 0.36 - 0.12 * step(0.62, rel) * step(0.45, r2) - 0.08 * step(0.85, rel) * step(0.70, r2);
                float body = step(abs(fx - 0.5), halfw) * step(up, th) * present;
                // slim antenna on the tallest towers
                float ant = step(0.80, r) * step(abs(fx - 0.5), 0.05) * step(th, up) * step(up, th + 0.018) * present * env;

                // glass: reflects the sky gradient (bright low, deeper blue higher up)
                float hh = clamp(up / 0.15, 0.0, 1.0);
                vec3 refl = mix(vec3(0.82, 0.95, 1.0), vec3(0.28, 0.58, 0.96), hh);
                vec3 col = mix(vec3(0.97, 0.99, 1.0), refl, 0.55 + 0.15 * r2);
                col *= mix(0.82, 1.0, smoothstep(0.38, 0.52, fx));               // shaded left face
                col += vec3(1.0) * 0.40 * smoothstep(0.60, 0.68, fx) * step(fx, 0.74);   // sun stripe
                col = mix(col, vec3(1.0), step(0.80, fract(up * 130.0)) * 0.28);         // floor lines
                col = mix(col, vec3(1.0), step(0.95, rel) * 0.7);                       // white crowns
                float m = body;

                // glass domes with a fresnel rim and a specular spot
                vec2 c1 = vec2(0.420, hz); vec2 c2 = vec2(0.605, hz);
                vec2 q1 = (p - c1) * vec2(1.7778, 1.0); vec2 q2 = (p - c2) * vec2(1.7778, 1.0);
                float d1 = length(q1) / 0.030; float d2 = length(q2) / 0.022;
                if (d1 < 1.0 || d2 < 1.0) {
                    vec2 q = d1 < 1.0 ? q1 / 0.030 : q2 / 0.022;
                    float d = d1 < 1.0 ? d1 : d2;
                    vec3 dome = mix(vec3(0.55, 0.85, 1.0), vec3(1.0), pow(d, 3.0));
                    dome += vec3(1.0) * smoothstep(0.30, 0.0, length(q - vec2(0.35, -0.55))) * 0.8;
                    col = dome; m = 1.0;
                }
                col = mix(col, vec3(1.0), ant);
                m = max(m, ant);
                col = mix(col, vec3(0.72, 0.90, 1.0), 0.27);                     // distance haze
                return vec4(col, m);
            }
            // swash: quick run-up, slow drain (0..1)
            float swash(float tt) { return pow(0.5 + 0.5 * sin(tt * 0.50), 1.7); }
            float waves(vec2 p) {
                float a = sin(p.x * 2.3 + t * 1.10 + sin(p.y * 1.7 + t * 0.6) * 1.6);
                float b = sin(p.y * 3.1 - t * 1.40 + sin(p.x * 1.3 - t * 0.5) * 1.4);
                float c = sin((p.x + p.y) * 4.7 + t * 1.9);
                return clamp((a * b * 0.75 + c * 0.25) * 0.5 + 0.5, 0.0, 1.0);
            }

            void main() {
                vec2 uv = qt_TexCoord0;
                float horizon = 0.43;
                vec2 sun = vec2(0.80, 0.20);
                // the shoreline breathes in and out, with a little ripple along it
                float ripple = 0.006 * sin(uv.x * 11.0 + t * 0.9) + 0.004 * sin(uv.x * 23.0 - t * 1.3);
                float shore = 0.578 + 0.020 * swash(t) + ripple;
                // how far up the sand the water reached in the last few seconds (wet sand)
                float reach = 0.578 + 0.020 * max(swash(t), max(swash(t - 1.5), max(swash(t - 3.0), swash(t - 4.5)))) + ripple;
                vec3 col;

                if (uv.y < horizon) {
                    float h = uv.y / horizon;
                    // pastel sky melting into a luminous white horizon
                    col = mix(vec3(0.06, 0.36, 0.90), vec3(0.58, 0.87, 1.0), pow(h, 1.45));
                    vec2 d = (uv - sun) * vec2(1.7778, 1.0);
                    float r = length(d);
                    col += vec3(1.0, 0.98, 0.90) * (exp(-r * 22.0) * 0.9 + exp(-r * 5.0) * 0.20);
                    // faint slow god rays
                    float ang = atan(d.y, d.x);
                    float rays = pow(0.5 + 0.5 * sin(ang * 11.0 + t * 0.04), 6.0) * pow(0.5 + 0.5 * sin(ang * 5.0 - t * 0.03), 3.0);
                    col += vec3(1.0, 0.98, 0.94) * rays * exp(-r * 2.6) * 0.10;
                    // puffy cumulus: density + a second sample toward the sun for self-shadowing
                    vec2 cp = vec2(uv.x * 2.4 + t * 0.011, uv.y * 4.4);
                    float dens = fbm(cp);
                    float band = smoothstep(0.06, 0.30, h) * (1.0 - smoothstep(0.80, 0.97, h));
                    float cov = smoothstep(0.54, 0.63, dens) * band;
                    float toward = fbm(cp + vec2(0.10, -0.12));
                    float lit = clamp(0.55 + (dens - toward) * 3.2 + (1.0 - h) * 0.15, 0.0, 1.0);
                    vec3 cloud = mix(vec3(0.66, 0.77, 0.94), vec3(1.0, 1.0, 1.0), lit);
                    cloud += vec3(1.0, 0.95, 0.85) * exp(-r * 6.0) * 0.35;       // sun-kissed edges
                    col = mix(col, cloud, cov * 0.96);
                    // glass city on the horizon
                    // the city as a mirage: fades into the haze toward its base
                    vec4 cty = city(uv, horizon);
                    float mist = 0.10 + 0.26 * smoothstep(0.06, 0.0, horizon - uv.y);
                    col = mix(col, mix(cty.rgb, vec3(0.82, 0.93, 1.0), mist), cty.a);
                    // luminous haze band hugging the horizon
                    col = mix(col, vec3(0.86, 0.95, 1.0), exp(-(horizon - uv.y) * 40.0) * 0.30);
                } else if (uv.y < shore) {
                    // --- sea: real-ish water. Wave normals -> fresnel sky reflection
                    // far away, see-through turquoise over rippled sand near the beach.
                    float y = uv.y - horizon;
                    float k = clamp(y / (shore - horizon), 0.0, 1.0);   // 0 horizon .. 1 shore
                    float z = 0.10 / max(y, 0.012);
                    vec2 wp = vec2((uv.x - 0.5) * z * 2.0, z * 1.6) + vec2(0.0, -t * 0.25);
                    float e = 0.07;
                    float h0 = waves(wp);
                    float hx = waves(wp + vec2(e, 0.0));
                    float hy = waves(wp + vec2(0.0, e));
                    float amp = mix(0.9, 0.35, k);                       // mirror-calm                        // calmer in the lagoon
                    vec3 n = normalize(vec3((h0 - hx) * amp, 1.0, (h0 - hy) * amp));
                    vec3 V = normalize(vec3((uv.x - 0.5) * 1.2, -(0.02 + y * 3.0), 1.0));
                    float cosT = clamp(dot(-V, n), 0.0, 1.0);
                    float F = 0.02 + 0.98 * pow(1.0 - cosT, 5.0);         // Schlick fresnel
                    vec3 R = reflect(V, n);
                    vec3 skyRefl = mix(vec3(0.70, 0.90, 1.0), vec3(0.14, 0.44, 0.90), clamp(R.y * 2.0, 0.0, 1.0));
                    vec3 S = normalize(vec3(0.38, 0.30, 1.0));
                    float spec = pow(max(dot(R, S), 0.0), 90.0);

                    // what you see through the water: body colour, then sand + caustics in the shallows
                    vec3 deep = mix(vec3(0.00, 0.40, 0.86), tint.rgb, 0.05);
                    vec3 lagoon = vec3(0.10, 0.86, 0.86);
                    vec3 body = mix(deep, lagoon, smoothstep(0.30, 1.0, k));
                    vec2 cp = wp * 2.2;
                    float ca = sin(cp.x * 3.0 + sin(cp.y * 2.0 + t * 1.1)) + sin(cp.y * 3.3 + sin(cp.x * 1.7 - t * 1.3));
                    float caus = pow(1.0 - clamp(abs(ca) * 0.5, 0.0, 1.0), 4.0);
                    vec3 seabed = vec3(0.86, 0.76, 0.54) * (0.70 + 0.55 * caus) * vec3(0.62, 0.96, 0.95);
                    float clear = smoothstep(0.45, 1.0, k);              // shallow water is crystal clear
                    vec3 under = mix(body, seabed, clear * 0.92);
                    col = mix(under, skyRefl, F);
                    col += vec3(1.0, 0.98, 0.94) * spec * 0.35;

                    // clean white wave lines rolling in toward the beach
                    float lp = k * 3.2 - t * 0.09;
                    float line = smoothstep(0.045, 0.0, abs(fract(lp) - 0.5)) * smoothstep(0.25, 0.65, k) * (1.0 - smoothstep(0.88, 0.98, k));
                    line *= 0.55 + 0.45 * noise(vec2(uv.x * 18.0 + floor(lp) * 7.0, floor(lp)));
                    col = mix(col, vec3(0.96, 1.0, 1.0), line * 0.55);

                    // thin glassy sheet of the swash: streaky sky reflections over the sand
                    float sheet = smoothstep(0.86, 1.0, k);
                    col += vec3(0.70, 0.90, 1.0) * sheet * 0.16 * (0.5 + 0.5 * sin(uv.x * 90.0 + h0 * 6.0 + t * 1.5));

                    // white caps out at sea, a breaking wave, and lacy foam at the water's edge
                    float caps = smoothstep(0.90, 0.98, h0) * 0.12 * (1.0 - k);
                    float bpos = 0.74 + 0.10 * swash(t - 1.2);
                    float breaker = smoothstep(0.030, 0.0, abs(k - bpos)) * (0.45 + 0.55 * noise(vec2(uv.x * 45.0, t * 0.7)));
                    float fd = shore - uv.y;
                    float lace = noise(vec2(uv.x * 70.0, uv.y * 140.0 + t * 0.9));
                    float edgeFoam = smoothstep(0.014, 0.0, fd) * (0.40 + 0.60 * lace);
                    col = mix(col, vec3(0.96, 0.99, 1.0), clamp(caps + breaker * 0.65 + edgeFoam * 0.9, 0.0, 1.0));

                    // the city mirrored in the water, broken up by the waves
                    if (y < 0.08) {
                        vec2 rp = vec2(uv.x + (h0 - 0.5) * 0.006, horizon - y * 1.1);
                        vec4 rc = city(rp, horizon);
                        col = mix(col, rc.rgb * 0.95, rc.a * 0.45 * (1.0 - smoothstep(0.0, 0.08, y)));
                    }
                    // horizon haze
                    col = mix(vec3(0.72, 0.91, 1.0), col, smoothstep(0.0, 0.05, y));
                } else {
                    // --- sand
                    float s = (uv.y - shore) / (1.0 - shore);           // 0 at shore .. 1 bottom
                    vec3 dry = vec3(1.00, 0.915, 0.71);                   // brighter, warmer sand
                    vec3 wet = vec3(0.84, 0.72, 0.53);
                    col = mix(wet, dry, smoothstep(0.0, 0.10, s));
                    // sand the last waves washed over: dark and glossy, drying out as the water drains
                    float wetz = clamp((reach + 0.004 - uv.y) / max(reach + 0.004 - shore, 0.002), 0.0, 1.0);
                    wetz *= step(uv.y, reach + 0.004);
                    col = mix(col, wet * 0.86, wetz * 0.85);
                    col = mix(col, vec3(0.62, 0.84, 0.97), wetz * wetz * 0.22);              // sky sheen
                    // permanently damp strip by the water
                    col = mix(col, vec3(0.55, 0.80, 0.95), smoothstep(0.04, 0.0, s) * 0.18);
                    // gentle dunes / grain
                    col *= 0.94 + 0.08 * noise(vec2(uv.x * 9.0, uv.y * 30.0));
                    // swaying palm-leaf shadows
                    vec2 sp = vec2(uv.x * 3.4 + 0.12 * sin(t * 0.45 + uv.y * 3.0), uv.y * 4.2 - 0.05 * sin(t * 0.33));
                    float n = noise(sp) * 0.65 + noise(sp * 2.7 + 3.1) * 0.35;
                    float shade = smoothstep(0.50, 0.66, n);
                    col *= 1.0 - 0.25 * shade;
                    // darken toward the bottom so the glass tiles pop
                    col *= 1.0 - 0.21 * smoothstep(0.05, 1.0, s);
                }
                // dreamy grade: softer saturation, highlight bloom, pale lift, gentle vignette
                float lum = dot(col, vec3(0.299, 0.587, 0.114));
                col = mix(vec3(lum), col, 1.06 + 0.20 * vib);   // saturation
                col = clamp(col, 0.0, 1.0);
                col = mix(col, col * col * (3.0 - 2.0 * col), 0.28 * vib);   // soft S-curve contrast
                col *= 1.0 + 0.05 * vib;                         // slight lift
                col += pow(max(col - 0.82, 0.0), vec3(2.0)) * 0.5;
                
                vec2 v = uv - 0.5;
                col *= 1.0 - dot(v, v) * 0.38;
                gl_FragColor = vec4(col, 1.0) * qt_Opacity;
            }"
    }
}
