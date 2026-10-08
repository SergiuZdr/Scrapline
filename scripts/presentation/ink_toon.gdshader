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

void fragment() {
	vec3 c = use_tex ? texture(albedo_tex, UV).rgb * albedo : albedo;
	if (use_tex && use_clean) {
		vec4 k = texture(clean_tex, UV);
		if (k.a < 0.999 && k.a <= clean) {
			c = k.rgb * albedo;
		}
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
	float band = 0.0;
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
