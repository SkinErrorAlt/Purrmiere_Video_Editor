shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D eighth_tex : filter_linear, repeat_disable;
uniform sampler2D sixteenth_tex : filter_linear, repeat_disable;
uniform sampler2D last_tex : filter_linear, repeat_disable;
uniform vec4 source_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 canvas_px = vec2(1920.0, 1080.0);
uniform int fill = 0;
uniform float blur : hint_range(0.0, 1.0) = 0.9;
uniform float zoom : hint_range(1.0, 3.0) = 1.1;
uniform float darken : hint_range(0.0, 1.0) = 0.3;
uniform float fill_saturation : hint_range(0.0, 2.0) = 1.1;
uniform vec4 colour : source_color = vec4(0.07, 0.07, 0.09, 1.0);
uniform float size : hint_range(0.2, 2.0) = 1.0;
uniform vec2 position = vec2(0.5, 0.5);
uniform float corner : hint_range(0.0, 0.5) = 0.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform float border : hint_range(0.0, 0.05) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 fill_uv(vec2 uv) {
	vec2 sz = max(source_box.zw, vec2(0.0001));
	float z = max(zoom, 1.0);
	if (fill == 1 || fill == 2) {
		vec2 box = sz * max(size, 0.01) * z;
		vec2 f = (uv - position) / box + 0.5;
		if (fill == 1) {
			return 1.0 - abs(1.0 - mod(f, 2.0));
		}
		return clamp(f, vec2(0.0), vec2(1.0));
	}
	float k = max(1.0 / sz.x, 1.0 / sz.y) * z;
	return 0.5 + (uv - 0.5) / (sz * k);
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

vec4 level(int i, vec2 uv) {
	if (i <= 0) {
		return texture(effect_tex, fill_uv(uv));
	}
	if (i == 1) {
		return smooth_sample(eighth_tex, uv);
	}
	if (i == 2) {
		return smooth_sample(sixteenth_tex, uv);
	}
	return smooth_sample(last_tex, uv);
}

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec4 over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

void fragment() {
	vec2 uv = UV;
	float asp = canvas_px.x / max(canvas_px.y, 1.0);
	vec4 bg = vec4(0.0);
	if (fill == 3) {
		bg = vec4(colour.rgb * colour.a, colour.a);
	} else if (fill < 3) {
		float b = clamp(blur, 0.0, 1.0) * 3.0;
		int lo = int(floor(b));
		float f = b - float(lo);
		bg = level(lo, uv);
		if (f > 0.001 && lo < 3) {
			bg = mix(bg, level(lo + 1, uv), f);
		}
		vec3 rgb = bg.a > 0.0001 ? bg.rgb / bg.a : vec3(0.0);
		float l = dot(rgb, LUMA);
		rgb = max(mix(vec3(l), rgb, clamp(fill_saturation, 0.0, 2.0)), vec3(0.0));
		rgb *= 1.0 - clamp(darken, 0.0, 1.0) * 0.85;
		bg = vec4(clamp(rgb, 0.0, 1.0) * bg.a, bg.a);
	}
	vec2 box = max(source_box.zw * max(size, 0.01), vec2(0.0001));
	vec2 fuv = (uv - position) / box + 0.5;
	vec2 q = (uv - position) * vec2(asp, 1.0);
	vec2 half_box = box * 0.5 * vec2(asp, 1.0);
	float rad = clamp(corner, 0.0, 0.5) * 2.0 * min(half_box.x, half_box.y);
	float d = box_sd(q, half_box, rad);
	float aa = max(length(fwidth(q)) * 0.7071, 0.000001);
	float cov = clamp(0.5 - d / aa, 0.0, 1.0);
	vec4 pic = texture(effect_tex, clamp(fuv, vec2(0.0), vec2(1.0))) * cov;
	float soft = 0.03;
	float ds = box_sd(q - vec2(0.0, 0.012), half_box, rad);
	float sh = clamp(shadow, 0.0, 1.0) * 0.75 * (1.0 - smoothstep(-soft, soft, ds));
	vec4 layer = over(vec4(0.0, 0.0, 0.0, sh), bg);
	float bw = clamp(border, 0.0, 0.05);
	if (bw > 0.0) {
		float ring = clamp(0.5 - (d - bw) / aa, 0.0, 1.0) * (1.0 - cov);
		layer = over(vec4(border_colour.rgb, 1.0) * border_colour.a * ring, layer);
	}
	COLOR = over(pic, layer);
}
