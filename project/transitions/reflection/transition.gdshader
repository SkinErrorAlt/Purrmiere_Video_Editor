shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float depth : hint_range(0.3, 3.0) = 1.2;
uniform float gap : hint_range(0.0, 1.0) = 0.25;
uniform float reflectivity : hint_range(0.0, 1.0) = 0.4;
uniform float falloff : hint_range(0.05, 1.0) = 0.45;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 card_hit(vec3 ro, vec3 rd, vec3 centre) {
	if (rd.z <= 0.000001) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	float t = (centre.z - ro.z) / rd.z;
	vec3 h = ro + rd * t - centre;
	float hw = tr_ratio() * 0.5;
	vec2 st = vec2(h.x / (hw * 2.0) + 0.5, 0.5 - h.y);
	if (t <= 0.0 || st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
		return vec4(st, 0.0, -1.0);
	}
	return vec4(st, 1.0, t);
}

vec4 settle(vec4 c, vec2 uv) {
	c = mix(c, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(c, to_at(uv), smoothstep(0.97, 1.0, progress));
}

vec4 pair(vec3 ro, vec3 rd, vec3 cf, vec3 ct, bool mirror, out float dist, out float height) {
	vec4 hf = card_hit(ro, rd, cf);
	vec4 ht = card_hit(ro, rd, ct);
	dist = -1.0;
	height = 0.0;
	vec4 h = hf;
	bool use_from = true;
	if (ht.w > 0.0 && (hf.w < 0.0 || ht.w < hf.w)) {
		h = ht;
		use_from = false;
	}
	if (h.w < 0.0) {
		return vec4(0.0);
	}
	dist = h.w;
	height = 1.0 - h.y;
	vec2 cuv = h.xy;
	if (mirror) {
		cuv.x = 1.0 - cuv.x;
	}
	return use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float back = depth * (tr_ease(p / 0.35, 3) - tr_ease((p - 0.65) / 0.35, 3));
	float slide = tr_ease((p - 0.2) / 0.6, 3);
	float pitch = tr_ratio() + gap;
	vec3 cf = vec3(-slide * pitch, 0.0, back);
	vec3 ct = vec3((1.0 - slide) * pitch, 0.0, back);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	bool mirror = direction == 1;
	if (mirror) {
		w.x = -w.x;
	}
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (rd.y < 0.0) {
		float tf = (-0.5 - ro.y) / rd.y;
		vec3 fp = ro + rd * tf;
		float rdist;
		float rh;
		vec4 rc = pair(fp, vec3(rd.x, -rd.y, rd.z), cf, ct, mirror, rdist, rh);
		float k = reflectivity * (1.0 - smoothstep(0.0, falloff, rh));
		res = tr_over(rc * k, res);
	}
	float dd;
	float dh;
	vec4 direct = pair(ro, rd, cf, ct, mirror, dd, dh);
	res = tr_over(direct, res);
	return settle(res, uv);
}

void fragment() {
	COLOR = transition(UV);
}
