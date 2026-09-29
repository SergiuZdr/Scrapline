// Ink & Rust (015): a mark on a board hex -- where you can go, what will be hit, what you are
// aiming at. Drawn like a colourist's overlay: a solid border just inside the hex edge and
// diagonal hatching across it, so a marked hex stays readable over any ground and in grey
// (the lines carry it, not the tint).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

uniform vec4 colour : source_color = vec4(0.2, 0.78, 0.88, 1.0);
// The hex's circumradius in the mesh's own units (a pointy-top CylinderMesh).
uniform float radius = 0.62;
// Border width as a fraction of the radius.
uniform float border = 0.09;
// Hatching: line period in metres (world space), the ink share of it, and its alpha.
uniform float hatch_period = 0.16;
uniform float hatch_width = 0.34;
uniform float hatch_alpha = 0.55;
// A light wash under the lines.
uniform float fill_alpha = 0.10;
// Dashed border (a drum's blast, a faint target): 0 solid, otherwise dash count around.
uniform float dashes = 0.0;
// Which way the hatching runs, so a mark's MEANING survives without colour: 1 one diagonal
// (where you can go), -1 the other (what will be hit), 0 both (what you are aiming at).
uniform float hatch_dir = 1.0;

varying vec3 local_pos;
varying vec3 world_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Distance to a pointy-top hex's edges (corner at +Z): 1.0 on the edge.
	vec2 p = abs(local_pos.xz);
	float d = max(p.x, p.x * 0.5 + p.y * 0.8660254) / (radius * 0.8660254);
	if (d > 1.0) {
		discard;
	}
	float a = fill_alpha;
	vec3 c = colour.rgb;
	bool one = fract((world_pos.x - world_pos.z) / hatch_period) < hatch_width;
	bool other = fract((world_pos.x + world_pos.z) / hatch_period) < hatch_width;
	if ((hatch_dir > 0.5 && one) || (hatch_dir < -0.5 && other) || (abs(hatch_dir) <= 0.5 && (one || other))) {
		a = max(a, hatch_alpha);
	}
	if (d > 1.0 - border) {
		bool on = true;
		if (dashes > 0.0) {
			float ang = atan(local_pos.z, local_pos.x) / 6.2831853 + 0.5;
			on = fract(ang * dashes) < 0.55;
		}
		if (on) {
			a = 1.0;
		}
	}
	ALBEDO = c;
	ALPHA = a * colour.a;
}
