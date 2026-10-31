shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D stars_tex : filter_linear, repeat_disable;
uniform float rate : hint_range(0.05, 3.0) = 0.9;
uniform float size : hint_range(20.0, 1500.0) = 300.0;
uniform int palette : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.22, 0.3, 1.0);
uniform int kind : hint_range(0, 4) = 0;
uniform float launch_x : hint_range(0.0, 1.0) = 0.5;
uniform float launch_area : hint_range(0.0, 1.0) = 0.7;
uniform float height : hint_range(0.0, 1.0) = 0.32;
uniform float glow : hint_range(0.0, 3.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.5;
uniform int blend : hint_range(0, 3) = 0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec4 h42(vec2 p) {
	vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

vec3 chem(float pick) {
	float k = floor(pick * 9.0);
	if (k < 1.0) { return vec3(1.0, 0.1, 0.07); }
	if (k < 2.0) { return vec3(0.2, 1.0, 0.22); }
	if (k < 3.0) { return vec3(0.22, 0.38, 1.0); }
	if (k < 4.0) { return vec3(0.72, 0.22, 1.0); }
	if (k < 5.0) { return vec3(1.0, 0.62, 0.16); }
	if (k < 6.0) { return vec3(0.82, 0.88, 1.0); }
	if (k < 7.0) { return vec3(1.0, 0.4, 0.05); }
	if (k < 8.0) { return vec3(0.15, 0.95, 0.85); }
	return vec3(1.0, 0.28, 0.62);
}

void fragment() {
	vec4 pic = texture(effect_tex, UV);
	float a0 = pic.a;
	vec3 rgb = a0 > 0.0001 ? pic.rgb / a0 : vec3(0.0);
	vec2 sz = max(tex_size * 2.0, vec2(1.0));
	float ps = max(px_scale * 2.0, 0.0001);
	vec2 p = UV * sz;
	float t = clip_time;
	float sd = mod(float(seed), 9973.0);
	float r8 = clamp(rate, 0.05, 3.0);
	vec3 fl = vec3(0.0);
	float last = floor(t * r8);
	int count = int(min(ceil(2.0 * r8) + 3.0, 14.0));
	for (int n = 0; n < count; n++) {
		float slot = last - float(n);
		vec4 hb = h42(vec2(slot * 1.37 + 11.0, sd * 0.731 + 5.0));
		vec4 hc = h42(vec2(slot * 2.11 + 3.0, sd * 1.173 + 17.0));
		float launch = (slot + 0.1 + 0.8 * hb.x) / r8;
		float bt = launch + 1.15 + 0.45 * hb.y;
		float a = t - bt;
		if (a < 0.0 || a > 1.6) {
			continue;
		}
		int kd = kind;
		if (kd == 0) {
			kd = hc.x < 0.38 ? 1 : (hc.x < 0.6 ? 4 : (hc.x < 0.8 ? 2 : 3));
		}
		vec2 lpos = vec2((launch_x + (hb.z - 0.5) * launch_area) * sz.x, sz.y);
		vec2 bpos = vec2(lpos.x + (hb.w - 0.5) * 0.08 * sz.x, clamp(height + (hc.y - 0.5) * 0.18, 0.02, 0.98) * sz.y);
		float scale = mix(0.78, 1.15, hc.z);
		vec3 base = palette == 1 || kd == 2 ? vec3(1.0, 0.66, 0.3) : (palette == 2 ? colour.rgb : chem(hc.w));
		vec3 c = mix(vec3(1.0, 0.92, 0.8), base, 0.55);
		float rr = size * ps * scale * 1.6;
		float d = length(p - bpos) / max(rr, 1.0);
		float env = exp(-a / 0.09) * 1.4 + exp(-a / 0.5) * 0.35;
		fl += c * env / (1.0 + d * d * 2.5);
	}
	fl *= flash;
	vec3 stars = texture(stars_tex, UV).rgb;
	vec3 gl = texture(TEXTURE, UV).rgb * (glow / 3.0) * 1.7;
	vec3 light = stars + gl;
	float dith = (h12(p + fract(t * 7.13) * 91.0) - 0.5) / 255.0;
	if (blend == 3) {
		vec3 o = light + fl * 0.18 + dith;
		COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
	} else {
		vec3 lp = rgb * (1.0 + fl * 2.0 + gl * 0.5) + fl * 0.1;
		vec3 o;
		if (blend == 1) {
			o = 1.0 - (1.0 - clamp(lp, 0.0, 1.0)) * (1.0 - clamp(light, 0.0, 1.0));
		} else if (blend == 2) {
			o = max(lp, light);
		} else {
			o = lp + light;
		}
		o += dith;
		COLOR = vec4(clamp(o, 0.0, 1.0) * a0, a0);
	}
}
