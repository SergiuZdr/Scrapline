// Ink & Rust (016): the unscouted map is UNFINISHED DRAWING -- the night page with loose
// pencil hatching over it, not a haze. Where the crew has seen, the page is inked: the yard
// shows through. The plan's line: "fog that means something".
//
// `mask` is painted on the CPU by YardView (1 = not scouted, 0 = seen). The edge is
// scribbled, not blurred: a noisy threshold on the mask, so the boundary reads as a pencil
// stopping, and noise never uncovers anything the mask keeps hidden.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 origin;        // world XZ of the mask's corner
uniform vec2 extent;        // world size the mask covers
uniform vec4 paper : source_color = vec4(0.07, 0.08, 0.11, 1.0);
uniform vec4 pencil : source_color = vec4(0.19, 0.21, 0.27, 1.0);
uniform float period = 0.85;   // metres between hatch strokes

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz - origin) / extent;
	float hidden = texture(mask, uv).r;
	vec2 p = world_pos.xz;
	float n = noise(p * 0.45);
	// The pencil stops raggedly: cover where the mask, nudged by noise, is past half.
	float cover = smoothstep(0.42, 0.5, hidden + (n - 0.5) * 0.3);
	if (cover <= 0.001) {
		discard;
	}
	// Two passes of hatching, wobbling like a hand, the second looser and fainter; strokes
	// break up here and there the way a pencil skips.
	float wob = noise(p * 0.9) * 0.35;
	float h1 = abs(fract((p.x + p.y) / period + wob) - 0.5);
	float h2 = abs(fract((p.x - p.y) / (period * 1.6) - wob * 0.6) - 0.5);
	float skip = step(0.25, noise(p * 2.3 + 11.0));
	float stroke = max(step(h1, 0.07) * skip, step(h2, 0.045) * 0.55);
	ALBEDO = mix(paper.rgb, pencil.rgb, stroke);
	ALPHA = cover;
}
