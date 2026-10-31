shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int axis = 0;
uniform int spin_way = 0;
uniform float gloss : hint_range(0.0, 1.0) = 0.6;
uniform float sharpness : hint_range(4.0, 200.0) = 30.0;
uniform float depth : hint_range(0.0, 2.0) = 0.25;
uniform float lens : hint_range(10.0, 90.0) = 45.0;
uniform float shading : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 turn_m(float a) {
	float c = cos(a);
	float s = sin(a);
	if (axis == 1) {
		return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
	}
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, 4);
	float a = TR_PI * e * (spin_way == 0 ? 1.0 : -1.0);
	mat3 m = turn_m(a);
	float lift = sin(TR_PI * e);
	vec3 centre = vec3(0.0, 0.0, depth * lift);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(tr_world(uv), 0.0) - ro);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (abs(dn) > 0.000001) {
		float t = dot(centre - ro, n) / dn;
		vec3 q = transpose(m) * (ro + rd * t - centre);
		if (t > 0.0 && abs(q.x) <= tr_ratio() * 0.5 && abs(q.y) <= 0.5) {
			bool front = dn < 0.0;
			vec2 lq = q.xy;
			if (!front) {
				if (axis == 1) {
					lq.y = -lq.y;
				} else {
					lq.x = -lq.x;
				}
			}
			vec2 cuv = tr_frame_uv(lq);
			vec4 c = front ? texture(from_tex, cuv) : texture(to_tex, cuv);
			vec3 face_n = front ? n : -n;
			vec3 refl = reflect(rd, face_n);
			vec3 light_dir = normalize(vec3(0.55, 0.45, -1.0));
			float spec = pow(max(dot(refl, light_dir), 0.0), sharpness) * gloss * lift * 1.5;
			float sheen = gloss * lift * 0.25 * (1.0 - abs(face_n.z));
			c = tr_shade(c, mix(1.0, abs(n.z), shading));
			c.rgb += vec3(spec + sheen) * c.a;
			res = tr_over(c, bg);
		}
	}
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
