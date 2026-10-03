// Ink & Rust (015): the ink line. An inverted hull -- back faces pushed out along the
// normal -- at a CONSTANT width on screen, so a machine far away and one close up are drawn
// with the same pen. Set as a mesh's `material_overlay`.
//
// The push uses the SMOOTHED normal that `Ink.hull_mesh` packs into UV2 (octahedral). A box's
// own normals are split at every edge, and pushing each face out along its own normal opens a
// crack at every corner: a broken line on exactly the silhouettes the style is built on.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 ink : source_color = vec4(0.078, 0.067, 0.059, 1.0);
// Width in pixels at 1080 lines; scaled with the viewport so a phone draws the same line.
uniform float width_px = 2.0;

vec3 oct_decode(vec2 e) {
	vec2 f = e * 2.0 - 1.0;
	vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
	float t = max(-n.z, 0.0);
	n.x += n.x >= 0.0 ? -t : t;
	n.y += n.y >= 0.0 ? -t : t;
	return normalize(n);
}

void vertex() {
	vec3 n = oct_decode(UV2);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_n = normalize(MODELVIEW_NORMAL_MATRIX * n);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_n, 0.0)).xy;
	float len = length(dir);
	if (len > 0.00001) {
		dir /= len;
	}
	float scale = max(VIEWPORT_SIZE.y / 1080.0, 0.5);
	// 039, the comic: a brush, not a technical pen -- the width swells and thins along the line
	// (by where on the model it is, so it holds still as the machine moves).
	float swell = 0.75 + 0.5 * (0.5 + 0.5 * sin(dot(VERTEX, vec3(7.1, 5.3, 6.7))));
	clip.xy += dir * width_px * swell * scale * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
