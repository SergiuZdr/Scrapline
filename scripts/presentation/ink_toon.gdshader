// Ink & Rust (015): flat colour in three bands -- lit, mid, ink shadow -- under one hard key.
//
// The lit band is the palette colour exactly: the key's HUE is used, never its energy, so a
// colour picked on paper is the colour on screen. The shadow band is what the scene's flat
// night ambient leaves (albedo x ambient). Between mid and shadow, halftone dots grow toward
// the shadow edge, the way print shades a curve. Metal gets one hard highlight stripe.
//
// Patterns are ink DRAWN on the surface in world space (so they stay put when a machine
// walks over them): stipple for rough ground, hatching for hazards.
shader_type spatial;
render_mode cull_back;

uniform vec3 albedo : source_color = vec3(0.5);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
// 053: a generated part's rust wears off as its machine levels up. `clean_tex` is the part's
// texture with the rust painted over (RGB) and, in ALPHA, the order each rust texel cleans in;
// a texel shows clean once `clean` (level / max level) reaches it. Untouched texels have alpha 1.
uniform sampler2D clean_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_clean = false;
uniform float clean = 0.0;
// Signals only: an emissive colour, added whatever the light.
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

// The ramp. Light below `shade_edge` is ink shadow; above `lit_edge` it is the full colour.
uniform float lit_edge = 0.42;
uniform float shade_edge = 0.14;
uniform float mid_level = 0.62;
uniform float key = 1.0;
// 0 = no halftone; 1 = dots up to 75% of a cell at the shadow edge.
uniform float halftone = 1.0;
uniform float dot_px = 5.0;
// 0 = matte; > 0 = one hard specular stripe (metal).
uniform float stripe = 0.0;
// 039, the comic: 1 = CROSS-HATCHING in the shade band (one diagonal, then both, toward the
// shadow) instead of a flat tone; `rim` = a white highlight stroke on the lit silhouette.
uniform float hatch = 0.0;
uniform float hatch_px = 6.0;
uniform float rim = 0.0;
// 067, the machines as a comic (the user: "a filter so they look as close as possible to a comic"):
// a generated part's painted texture is PRINTED -- its colour read a little blurred (so photo grain
// does not speckle), its value posterised into `comic_levels` flat steps with the hue kept and
// pushed, and its darkest texels (rust pits, seams, recesses) inked solid.
uniform float comic = 0.0;
uniform float comic_levels = 4.0;
uniform float comic_ink = 0.15;
uniform float comic_sat = 1.15;
// 068: ink lines DRAWN where the texture's value changes sharply (panel seams, plate edges, rust
// borders): a value gradient read across `comic_edge_px` screen pixels, so the line keeps its width
// at any distance; above `comic_edge` it is inked.
uniform float comic_edge = 0.09;
uniform float comic_edge_px = 1.6;
// 080 (the user: "some parts look practically all black, from the outline to tiny details"): the
// mip the edge is read from (higher ignores a generated texture's speckle), the darkest step a
// posterised texel may print at (it was near black), and the value of the unlit side (0 = black).
uniform float comic_edge_lod = 1.2;
uniform float comic_floor = 0.0;
uniform float shadow_level = 0.0;

// 085: a weekly contract's livery repaints a generated part's PAINTED texels and nothing else: the
// saturated, lit-enough panels. Yellow panels (the frame's paint) take `livery_paint`, red and orange
// panels that are bright enough to be paint, not rust, take `livery_trim`; grey steel, black mechanism
// and dark rust keep the texture. Each texel keeps its own value (scaled from a typical panel's), so
// chips, stains and wear stay. Colours are sRGB (no source_color hint); the work is done in sRGB.
// Ink edges are read from the original texture, so the line work is the same in every livery.
uniform bool livery_on = false;
uniform vec3 livery_paint = vec3(0.85, 0.64, 0.25);
uniform vec3 livery_trim = vec3(0.61, 0.23, 0.18);
// > 0: blotches of the trim colour over the paint (camouflage), in the texture's own space.
uniform float livery_camo = 0.0;
// The value (max channel, sRGB) of a typical painted panel in the generated textures.
uniform float livery_ref_paint = 0.48;
uniform float livery_ref_trim = 0.45;

// 0 none, 1 stipple dots, 2 diagonal hatching.
uniform int pattern = 0;
uniform vec3 pattern_colour : source_color = vec3(0.078, 0.067, 0.059);
uniform float pattern_scale = 8.0;
uniform float pattern_amount = 0.0;

varying vec3 world_pos;
varying float dot_dist;
varying float hatch_a;
varying float hatch_b;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 085: a texel of a generated part in its livery (see the uniforms).
vec3 repaint(vec3 c, vec2 uv) {
	vec3 s = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
	vec3 hsv = rgb2hsv(s);
	float h = hsv.x;
	float yellow = smoothstep(0.075, 0.1, h) * (1.0 - smoothstep(0.2, 0.26, h));
	float red = 1.0 - smoothstep(0.075, 0.1, h) + smoothstep(0.9, 0.95, h);
	float paint_w = yellow * smoothstep(0.28, 0.42, hsv.y) * smoothstep(0.18, 0.3, hsv.z);
	// Red and orange are paint only when bright: dark orange is rust and stays rust.
	float trim_w = red * smoothstep(0.35, 0.5, hsv.y) * smoothstep(0.3, 0.42, hsv.z);
	vec3 paint = livery_paint;
	if (livery_camo > 0.0) {
		float n = value_noise(uv * 9.0) * 0.65 + value_noise(uv * 23.0) * 0.35;
		paint = mix(paint, livery_trim, step(0.52, n) * livery_camo);
	}
	vec3 out_s = s;
	out_s = mix(out_s, clamp(paint * min(hsv.z / livery_ref_paint, 1.3), 0.0, 1.0), paint_w);
	out_s = mix(out_s, clamp(livery_trim * min(hsv.z / livery_ref_trim, 1.3), 0.0, 1.0), trim_w);
	return pow(out_s, vec3(2.2));
}

void fragment() {
	vec3 c = use_tex ? texture(albedo_tex, UV, comic > 0.0 ? 1.2 : 0.0).rgb : albedo;
	if (use_tex && use_clean) {
		vec4 k = texture(clean_tex, UV);
		if (k.a < 0.999 && k.a <= clean) {
			c = texture(clean_tex, UV, comic > 0.0 ? 1.2 : 0.0).rgb;
		}
	}
	if (use_tex && livery_on) {
		c = repaint(c, UV);
	}
	if (use_tex && comic > 0.0) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		float q = max((floor(l * comic_levels) + 0.55) / comic_levels, comic_floor);
		vec3 printed = clamp(mix(vec3(q), c / max(l, 0.001) * q, comic_sat), 0.0, 1.0);
		vec2 du = dFdx(UV) * comic_edge_px;
		vec2 dv = dFdy(UV) * comic_edge_px;
		vec3 w = vec3(0.299, 0.587, 0.114);
		float gx = dot(texture(albedo_tex, UV + du, comic_edge_lod).rgb - texture(albedo_tex, UV - du, comic_edge_lod).rgb, w);
		float gy = dot(texture(albedo_tex, UV + dv, comic_edge_lod).rgb - texture(albedo_tex, UV - dv, comic_edge_lod).rgb, w);
		if (l < comic_ink || length(vec2(gx, gy)) > comic_edge) {
			printed = vec3(0.078, 0.067, 0.059);
		}
		c = mix(c, printed, comic);
	}
	if (use_tex) {
		c *= albedo;
	}
	if (pattern == 1) {
		vec2 p = world_pos.xz * pattern_scale;
		vec2 cell = floor(p);
		float h = hash(cell);
		vec2 f = fract(p) - 0.5 - (vec2(h, hash(cell + 7.1)) - 0.5) * 0.45;
		if (h < pattern_amount && length(f) < 0.13 + 0.08 * hash(cell + 3.3)) {
			c = pattern_colour;
		}
	} else if (pattern == 2) {
		if (fract((world_pos.x + world_pos.z) * pattern_scale) < pattern_amount) {
			c = pattern_colour;
		}
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = emission * emission_energy;
	// Halftone cells in SCREEN space, scaled with the resolution so a phone sees the same dots.
	float px = dot_px * max(VIEWPORT_SIZE.y / 1080.0, 0.5);
	vec2 g = fract(FRAGCOORD.xy / px) - 0.5;
	dot_dist = length(g);
	float hp = hatch_px * max(VIEWPORT_SIZE.y / 1080.0, 0.5);
	hatch_a = fract((FRAGCOORD.x + FRAGCOORD.y) / hp);
	hatch_b = fract((FRAGCOORD.x - FRAGCOORD.y) / hp);
}

void light() {
	// Only the key draws: a stray omni light would add a fourth band.
	float l = LIGHT_IS_DIRECTIONAL ? clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION : -1.0;
	float band = shadow_level;
	if (l > lit_edge) {
		band = 1.0;
	} else if (l > shade_edge) {
		band = mid_level;
		if (hatch > 0.0) {
			float t = 1.0 - (l - shade_edge) / max(lit_edge - shade_edge, 0.001);
			if ((t > 0.35 && hatch_a < 0.16) || (t > 0.7 && hatch_b < 0.16)) {
				band = 0.0;
			}
		}
		if (halftone > 0.0) {
			float t = 1.0 - (l - shade_edge) / max(lit_edge - shade_edge, 0.001);
			if (dot_dist < t * t * 0.75 * halftone) {
				band = 0.0;
			}
		}
	}
	vec3 hue = LIGHT_COLOR / max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), max(LIGHT_COLOR.b, 0.0001));
	DIFFUSE_LIGHT += hue * band * key;
	if (rim > 0.0 && l > shade_edge) {
		float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		if (edge > 0.8) {
			SPECULAR_LIGHT += vec3(rim);
		}
	}
	if (stripe > 0.0 && l > 0.0 && ATTENUATION > 0.5) {
		vec3 h = normalize(LIGHT + VIEW);
		if (dot(NORMAL, h) > 0.985) {
			SPECULAR_LIGHT += hue * stripe;
		}
	}
}
