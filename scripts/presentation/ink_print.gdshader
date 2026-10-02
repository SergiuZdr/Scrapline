// 036, comic style (play-test 10: "more of a comic's art style"): the 3D world as a printed
// page. Drawn over the world and under the HUD (a CanvasLayer below the HUD's), it reads what
// was rendered and prints it:
//   - misregistration: the red and blue plates a pixel or so off, the way cheap print slips;
//   - a dot screen in the shadows: the darker a pixel, the bigger its dot, on a 45 degree screen;
//   - paper: grain over everything, and the highlights warmed toward newsprint.
// Signals keep their colour: the shift is small and the dots only darken, never recolour.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform sampler2D paper : repeat_enable, filter_linear;
uniform float shift_px = 1.5;
uniform float dot_px = 6.0;
uniform float dot_strength = 0.6;
uniform float dot_below = 0.3;
uniform float grain = 0.09;
uniform float warm = 0.06;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float scale = max(1.0 / (px.y * 1080.0), 0.5);
	vec3 c = texture(screen, uv).rgb;
	float r = texture(screen, uv + vec2(-shift_px, 0.4 * shift_px) * px * scale).r;
	float b = texture(screen, uv + vec2(0.8 * shift_px, -0.5 * shift_px) * px * scale).b;
	c = vec3(mix(c.r, r, 0.7), c.g, mix(c.b, b, 0.7));

	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 p = FRAGCOORD.xy / (dot_px * scale);
	p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
	float d = length(fract(p) - 0.5);
	float radius = clamp((dot_below - l) / dot_below, 0.0, 1.0) * 0.62;
	if (d < radius) {
		c *= 1.0 - dot_strength;
	}

	float n = texture(paper, FRAGCOORD.xy / (512.0 * scale)).r;
	c *= 1.0 + grain * (n - 0.5) * 2.0;
	c = mix(c, c * vec3(1.04, 1.0, 0.9), warm * smoothstep(0.35, 0.9, l));
	COLOR = vec4(c, 1.0);
}
