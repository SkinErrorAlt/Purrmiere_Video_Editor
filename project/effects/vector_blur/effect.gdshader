shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 60.0) = 10.0;
uniform float angle_offset : hint_range(-180.0, 180.0) = 0.0;
uniform float ridge : hint_range(0.5, 20.0) = 3.0;
uniform bool edges_only = true;
uniform vec2 tex_size;
uniform float px_scale;

float lu(sampler2D t, vec2 p) {
	vec4 s = texture(t, p);
	return dot(s.rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	float ps = max(px_scale, 0.0001);
	vec2 px = vec2(ps) / max(tex_size, vec2(1.0));
	vec2 e = px * ridge;
	vec2 g = vec2(lu(TEXTURE, UV + vec2(e.x, 0.0)) - lu(TEXTURE, UV - vec2(e.x, 0.0)), lu(TEXTURE, UV + vec2(0.0, e.y)) - lu(TEXTURE, UV - vec2(0.0, e.y)));
	g += 0.5 * vec2(lu(TEXTURE, UV + vec2(e.x, e.y)) - lu(TEXTURE, UV - vec2(e.x, e.y)) + lu(TEXTURE, UV + vec2(e.x, -e.y)) - lu(TEXTURE, UV - vec2(e.x, -e.y)), lu(TEXTURE, UV + vec2(e.x, e.y)) - lu(TEXTURE, UV - vec2(e.x, e.y)) - lu(TEXTURE, UV + vec2(e.x, -e.y)) + lu(TEXTURE, UV - vec2(e.x, -e.y)));
	float m = length(g);
	vec2 dir = m > 0.00001 ? vec2(-g.y, g.x) / m : vec2(1.0, 0.0);
	float a = radians(angle_offset);
	dir = vec2(cos(a) * dir.x - sin(a) * dir.y, sin(a) * dir.x + cos(a) * dir.y);
	float len = amount * (edges_only ? smoothstep(0.0, 0.08, m) : 1.0);
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 13; i++) {
		float t = float(i) / 12.0 - 0.5;
		float w = 1.0 - abs(t);
		sum += texture(TEXTURE, UV + dir * t * len * px) * w;
		wsum += w;
	}
	COLOR = sum / wsum;
}
