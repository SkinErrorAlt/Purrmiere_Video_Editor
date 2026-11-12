shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D l1 : filter_linear, repeat_disable;
uniform sampler2D l2 : filter_linear, repeat_disable;
uniform sampler2D l3 : filter_linear, repeat_disable;
uniform sampler2D l4 : filter_linear, repeat_disable;
uniform float translucency : hint_range(0.0, 1.0) = 0.7;
uniform float scatter : hint_range(0.0, 1.0) = 0.6;
uniform vec4 scatter_colour : source_color = vec4(1.0, 0.42, 0.25, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.4;
uniform float skin_hue : hint_range(0.0, 360.0) = 22.0;
uniform float skin_width : hint_range(5.0, 120.0) = 40.0;
uniform bool skin_only = true;
uniform bool show_mask = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 rgb_to_hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.00001) {
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
	}
	float s = mx > 0.00001 ? d / mx : 0.0;
	return vec3(h * 60.0, s, mx);
}

float skin_mask(vec3 rgb) {
	vec3 hsv = rgb_to_hsv(clamp(rgb, 0.0, 1.0));
	float dh = abs(hsv.x - mod(skin_hue, 360.0));
	dh = min(dh, 360.0 - dh);
	float half_w = max(skin_width * 0.5, 1.0);
	float hue_w = 1.0 - smoothstep(half_w * 0.6, half_w + 8.0, dh);
	float sat_w = smoothstep(0.08, 0.2, hsv.y) * (1.0 - smoothstep(0.75, 0.95, hsv.y));
	float val_w = smoothstep(0.05, 0.16, hsv.z);
	if (!skin_only) {
		float warm = 1.0 - smoothstep(35.0, 70.0, dh);
		return warm * sat_w * val_w;
	}
	return hue_w * sat_w * val_w;
}

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec4 smooth_sample(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 inv = 1.0 / size;
	vec2 p = uv * size - 0.5;
	vec2 fxy = fract(p);
	p -= fxy;
	vec4 xc = cubic(fxy.x);
	vec4 yc = cubic(fxy.y);
	vec4 c = p.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 off = c + vec4(xc.yw, yc.yw) / s;
	off *= inv.xxyy;
	vec4 s0 = texture(tex, off.xz);
	vec4 s1 = texture(tex, off.yz);
	vec4 s2 = texture(tex, off.xw);
	vec4 s3 = texture(tex, off.yw);
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
}

vec3 norm(vec4 v, vec3 fallback) {
	return v.a > 0.002 ? v.rgb / v.a : fallback;
}

vec3 at_level(float k, vec3 c0, vec3 c1, vec3 c2, vec3 c3) {
	float x = clamp(k, 0.0, 3.0);
	vec3 a = mix(c0, c1, clamp(x, 0.0, 1.0));
	vec3 b = mix(c1, c2, clamp(x - 1.0, 0.0, 1.0));
	vec3 c = mix(c2, c3, clamp(x - 2.0, 0.0, 1.0));
	return x < 1.0 ? a : (x < 2.0 ? b : c);
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	vec3 rgb = a > 0.0001 ? o.rgb / a : vec3(0.0);
	float m = skin_mask(rgb) * step(0.0001, a);
	vec4 w0 = texture(l1, UV);
	vec3 c0 = norm(w0, rgb);
	vec3 c1 = norm(smooth_sample(l2, UV), c0);
	vec3 c2 = norm(smooth_sample(l3, UV), c1);
	vec3 c3 = norm(smooth_sample(l4, UV), c2);
	float sc = clamp(scatter, 0.0, 1.0);
	vec3 col = clamp(scatter_colour.rgb, 0.0, 1.0);
	float ref_k = 0.5 + 2.5 * sc * 0.42;
	vec3 ref_c = at_level(ref_k, c0, c1, c2, c3);
	vec3 deep = vec3(0.0);
	deep.r = at_level(0.5 + 2.5 * sc * col.r, c0, c1, c2, c3).r;
	deep.g = at_level(0.5 + 2.5 * sc * col.g, c0, c1, c2, c3).g;
	deep.b = at_level(0.5 + 2.5 * sc * col.b, c0, c1, c2, c3).b;
	float cover = smooth_sample(l3, UV).a;
	float conf = smoothstep(0.35, 0.8, cover);
	float amt = clamp(translucency, 0.0, 1.0) * m * conf;
	vec3 ratio = clamp(deep / max(ref_c, vec3(0.02)), vec3(0.96, 0.9, 0.88), vec3(1.8));
	vec3 outc = rgb * mix(vec3(1.0), ratio, amt * 2.2);
	float wide = dot(c3, LUMA);
	float mid = smoothstep(0.08, 0.45, wide) * (1.0 - smoothstep(0.75, 1.0, wide));
	vec3 glow_c = col / max(max(col.r, max(col.g, col.b)), 0.001);
	outc += glow_c * wide * mid * clamp(glow, 0.0, 1.0) * amt * 0.22;
	outc = clamp(outc, 0.0, 1.0);
	if (show_mask) {
		outc = vec3(m);
	}
	COLOR = vec4(outc * a, a);
}
