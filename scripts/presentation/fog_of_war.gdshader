// Fog of war over the region map (play-test 4: "the map should not be seen whole from
// the start"). A few of these planes are stacked a metre apart so the haze has depth.
//
// `mask` is painted on the CPU by YardView: 1 where nothing has been scouted, 0 around
// every site the crew has seen and along the roads between them. The noise only moves
// the haze about; it never uncovers anything the mask keeps hidden.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 origin;        // world XZ of the mask's corner
uniform vec2 extent;        // world size the mask covers
uniform vec4 tint : source_color = vec4(0.05, 0.05, 0.065, 1.0);
uniform float density = 0.9;
uniform float drift = 0.02;
uniform float seed = 0.0;

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
	vec2 flow = vec2(TIME * drift, TIME * drift * 0.6) + seed;
	float n = noise(world_pos.xz * 0.12 + flow) * 0.6 + noise(world_pos.xz * 0.37 - flow * 1.7) * 0.4;
	ALBEDO = tint.rgb + vec3(n * 0.035);
	ALPHA = clamp(hidden * density * (0.72 + n * 0.45), 0.0, 0.98);
}
