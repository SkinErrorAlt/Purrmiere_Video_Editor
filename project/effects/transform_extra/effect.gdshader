shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float skew_x : hint_range(-1.0, 1.0) = 0.0;
uniform float skew_y : hint_range(-1.0, 1.0) = 0.0;
uniform float tilt : hint_range(-89.0, 89.0) = 0.0;
uniform float swivel : hint_range(-89.0, 89.0) = 0.0;
uniform float distance : hint_range(0.5, 4.0) = 1.5;
uniform float lens : hint_range(0.5, 4.0) = 1.5;
uniform float scale : hint_range(0.1, 4.0) = 1.0;
uniform bool edge = false;

void fragment() {
	vec2 aspect = vec2(tex_size.x / max(tex_size.y, 1.0), 1.0);
	vec2 p = (UV - 0.5) * 2.0 * aspect / max(scale, 0.01);
	float rx = radians(tilt);
	float ry = radians(swivel);
	float focal = max(lens, 0.01);
	vec3 ro = vec3(0.0, 0.0, -max(distance, 0.01));
	vec3 rd = normalize(vec3(p.x, p.y, focal));
	vec3 n = vec3(0.0, 0.0, 1.0);
	mat3 mx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(rx), -sin(rx)), vec3(0.0, sin(rx), cos(rx)));
	mat3 my = mat3(vec3(cos(ry), 0.0, sin(ry)), vec3(0.0, 1.0, 0.0), vec3(-sin(ry), 0.0, cos(ry)));
	mat3 rot = my * mx;
	vec3 nn = rot * n;
	vec3 ax = rot * vec3(1.0, 0.0, 0.0);
	vec3 ay = rot * vec3(0.0, 1.0, 0.0);
	float denom = dot(rd, nn);
	vec4 outc = vec4(0.0);
	if (abs(denom) > 0.0001) {
		float t = dot(-ro, nn) / denom;
		if (t > 0.0) {
			vec3 hit = ro + rd * t;
			vec2 q = vec2(dot(hit, ax), dot(hit, ay));
			q.x -= q.y * skew_x;
			q.y -= q.x * skew_y;
			vec2 uv = q / aspect * 0.5 + 0.5;
			if (edge || (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)) {
				outc = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
			}
		}
	}
	COLOR = outc;
}
