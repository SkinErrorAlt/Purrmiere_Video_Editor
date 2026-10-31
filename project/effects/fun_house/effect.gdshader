shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float stretch : hint_range(-1.0, 1.0) = 0.35;
uniform float width : hint_range(0.05, 2.0) = 0.6;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform bool mirror = false;
uniform int edges = 1;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 1) {
		uv = 1.0 - abs(1.0 - mod(uv, 2.0));
	} else if (edges == 2) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float a = radians(angle);
	vec2 ax = vec2(cos(a), sin(a));
	vec2 ay = vec2(-ax.y, ax.x);
	float u = dot(d, ax);
	float v = dot(d, ay);
	if (mirror) {
		u = abs(u);
	}
	float s = max(1.0 + clamp(stretch, -1.0, 1.0) * 0.9 * cos(6.28318530718 * v / max(width, 0.001)), 0.1);
	vec2 q = ax * (u / s) + ay * v;
	COLOR = fetch(TEXTURE, centre + q / aspect);
}
