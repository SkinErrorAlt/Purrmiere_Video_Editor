shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D near_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform sampler2D far_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform vec2 position = vec2(0.5, 0.82);
uniform float width : hint_range(0.05, 1.0) = 0.62;
uniform float height : hint_range(0.03, 1.0) = 0.16;
uniform float roundness : hint_range(0.0, 0.5) = 0.3;
uniform float blur : hint_range(0.0, 1.0) = 0.75;
uniform vec4 tint : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.4;
uniform float edge : hint_range(0.0, 1.0) = 0.5;
uniform float shadow : hint_range(0.0, 1.0) = 0.35;
uniform int animate = 0;
uniform float anim_time : hint_range(0.05, 2.0) = 0.35;

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec4 cubic_w(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec4 smooth_sample(sampler2D tex, vec2 uv) {
	vec2 ts = max(vec2(textureSize(tex, 0)), vec2(1.0));
	vec2 t = uv * ts - 0.5;
	vec2 f = fract(t);
	t -= f;
	vec4 xc = cubic_w(f.x);
	vec4 yc = cubic_w(f.y);
	vec4 c = t.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 o = (c + vec4(xc.yw, yc.yw) / s) / ts.xxyy;
	vec4 a = texture(tex, o.xz);
	vec4 b = texture(tex, o.yz);
	vec4 d = texture(tex, o.xw);
	vec4 e = texture(tex, o.yw);
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(e, d, sx), mix(b, a, sx), sy);
}

vec4 frosted(vec2 uv, float b) {
	float x = clamp(b, 0.0, 1.0) * 3.0;
	if (x < 1.0) {
		return mix(texture(effect_tex, uv), smooth_sample(near_tex, uv), x);
	}
	if (x < 2.0) {
		return mix(smooth_sample(near_tex, uv), smooth_sample(mid_tex, uv), x - 1.0);
	}
	return mix(smooth_sample(mid_tex, uv), smooth_sample(far_tex, uv), x - 2.0);
}

vec4 over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

void fragment() {
	vec2 res = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float asp = res.x / res.y;
	vec4 pic = texture(effect_tex, UV);
	float at = max(anim_time, 0.01);
	float k = animate == 2 ? 1.0 : clamp(min(clip_time, clip_duration - clip_time) / at, 0.0, 1.0);
	float e = 1.0 - pow(1.0 - k, 3.0);
	float fade = animate == 0 ? e : (animate == 1 ? clamp(k * 2.0, 0.0, 1.0) : 1.0);
	float rise = animate == 1 ? (1.0 - e) * 0.06 : 0.0;
	vec2 q = UV * vec2(asp, 1.0);
	vec2 c = position * vec2(asp, 1.0) + vec2(0.0, rise);
	vec2 hb = vec2(clamp(width, 0.05, 1.0) * asp, clamp(height, 0.03, 1.0)) * 0.5;
	float rad = clamp(roundness, 0.0, 0.5) * 2.0 * min(hb.x, hb.y);
	float aa = max(length(fwidth(q)) * 0.7071, 0.000001);
	float d = box_sd(q - c, hb, rad);
	float cov = clamp(0.5 - d / aa, 0.0, 1.0) * fade;
	vec4 out_c = pic;
	float soft = 0.02 + hb.y * 0.3;
	float ds = box_sd(q - c - vec2(0.0, 0.012), hb, rad);
	out_c = over(vec4(0.0, 0.0, 0.0, clamp(shadow, 0.0, 1.0) * 0.55 * fade * (1.0 - smoothstep(-soft, soft, ds)) * (1.0 - cov)), out_c);
	if (cov > 0.0) {
		vec4 fr = frosted(UV, blur);
		vec3 rgb = fr.a > 0.0001 ? fr.rgb / fr.a : vec3(0.0);
		float ta = clamp(tint_amount, 0.0, 1.0) * tint.a;
		rgb = mix(rgb, tint.rgb, ta);
		float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		rgb = mix(vec3(lum), rgb, 0.85);
		float rim = clamp(0.5 - (abs(d + aa * 1.2) - aa * 0.9) / aa, 0.0, 1.0);
		float top_light = clamp(1.0 - (q.y - (c.y - hb.y)) / max(hb.y * 2.0, 0.0001), 0.0, 1.0);
		rgb += vec3(1.0) * rim * clamp(edge, 0.0, 1.0) * (0.25 + 0.45 * top_light);
		rgb += vec3(1.0) * clamp(edge, 0.0, 1.0) * 0.06 * top_light;
		vec4 glass = vec4(clamp(rgb, 0.0, 1.0), 1.0);
		out_c = over(glass * cov, out_c);
	}
	COLOR = out_c;
}
