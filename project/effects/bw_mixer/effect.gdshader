shader_type canvas_item;
render_mode blend_disabled;

uniform int preset : hint_range(0, 7) = 1;
uniform float reds : hint_range(-200.0, 300.0) = 40.0;
uniform float yellows : hint_range(-200.0, 300.0) = 60.0;
uniform float greens : hint_range(-200.0, 300.0) = 40.0;
uniform float cyans : hint_range(-200.0, 300.0) = 60.0;
uniform float blues : hint_range(-200.0, 300.0) = 20.0;
uniform float magentas : hint_range(-200.0, 300.0) = 80.0;
uniform vec4 tint : source_color = vec4(0.86, 0.72, 0.52, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 chroma_of(vec3 rgb) {
	float y = dot(rgb, LUMA);
	return vec2((rgb.b - y) / 1.8556, (rgb.r - y) / 1.5748);
}

vec3 from_ycc(float y, vec2 cbcr) {
	float r = y + 1.5748 * cbcr.y;
	float b = y + 1.8556 * cbcr.x;
	float g = (y - 0.2126 * r - 0.0722 * b) / 0.7152;
	return vec3(r, g, b);
}

float grey_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float md = c.r + c.g + c.b - mx - mn;
	float primary;
	float secondary;
	if (c.r >= c.g && c.r >= c.b) {
		primary = reds;
		secondary = c.g >= c.b ? yellows : magentas;
	} else if (c.g >= c.b) {
		primary = greens;
		secondary = c.r >= c.b ? yellows : cyans;
	} else {
		primary = blues;
		secondary = c.g >= c.r ? cyans : magentas;
	}
	return mn + (md - mn) * secondary * 0.01 + (mx - md) * primary * 0.01;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float g = clamp(grey_of(rgb), 0.0, 1.0);
	float edge = smoothstep(0.0, 0.15, g) * (1.0 - smoothstep(0.85, 1.0, g));
	float strength = preset >= 0 ? tint_amount : 0.0;
	vec3 outc = from_ycc(g, chroma_of(tint.rgb) * strength * edge * 1.5);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
