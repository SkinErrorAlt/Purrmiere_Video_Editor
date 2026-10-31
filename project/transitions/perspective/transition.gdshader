shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float angle : hint_range(0.0, 75.0) = 40.0;
uniform float depth : hint_range(0.0, 3.0) = 1.0;
uniform float gap : hint_range(0.0, 0.5) = 0.08;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 settle(vec4 c, vec2 uv) {
	c = mix(c, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(c, to_at(uv), smoothstep(0.97, 1.0, progress));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 4);
	float lift = sin(TR_PI * e);
	bool vertical = direction >= 2;
	bool mirror = direction == 1 || direction == 3;
	vec2 w = tr_world(uv);
	if (vertical) {
		w = vec2(-w.y, w.x);
	}
	if (mirror) {
		w.x = -w.x;
	}
	float half_len = vertical ? 0.5 : tr_ratio() * 0.5;
	float half_cross = vertical ? tr_ratio() * 0.5 : 0.5;
	float pitch = half_len * 2.0 + gap;
	float shift = e * pitch;
	mat3 m = rot_y(radians(angle) * lift);
	vec3 pivot = vec3(0.0, 0.0, depth * lift);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (dn < -0.000001) {
		float t = dot(pivot - ro, n) / dn;
		vec3 q = transpose(m) * (ro + rd * t - pivot);
		float xl = q.x + shift;
		bool second = xl > half_len + gap * 0.5;
		float lx = second ? xl - pitch : xl;
		if (t > 0.0 && abs(lx) <= half_len && abs(q.y) <= half_cross) {
			vec2 cw = vec2(lx, q.y);
			if (mirror) {
				cw.x = -cw.x;
			}
			if (vertical) {
				cw = vec2(cw.y, -cw.x);
			}
			vec2 cuv = tr_frame_uv(cw);
			vec4 c = second ? texture(to_tex, cuv) : texture(from_tex, cuv);
			float light = mix(1.0, abs(n.z), shading);
			res = tr_over(tr_shade(c, light), bg);
		}
	}
	return settle(res, uv);
}

void fragment() {
	COLOR = transition(UV);
}
