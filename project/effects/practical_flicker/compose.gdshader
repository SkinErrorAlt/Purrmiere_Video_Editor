shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int mode : hint_range(0, 2) = 0;
uniform float threshold : hint_range(0.0, 1.0) = 0.75;
uniform float room : hint_range(0.0, 1.0) = 0.3;
uniform float warmth : hint_range(0.0, 1.0) = 0.5;

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec3 smooth_sample(sampler2D tex, vec2 uv) {
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
	vec3 s0 = texture(tex, off.xz).rgb;
	vec3 s1 = texture(tex, off.yz).rgb;
	vec3 s2 = texture(tex, off.xw).rgb;
	vec3 s3 = texture(tex, off.yw).rgb;
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	vec3 r = mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
	return r * r;
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec3 rgb = o.a > 0.0001 ? o.rgb / o.a : vec3(0.0);
	vec3 sg = smooth_sample(TEXTURE, UV);
	float s = sg.x;
	float g = s > 0.000001 ? 1.0 - sg.y / s + sg.z * 0.25 / s : 1.0;
	g = mix(1.0, g, smoothstep(0.00002, 0.0005, s));
	float w = s * 300.0 / (s * 300.0 + mix(0.05, 1.5, clamp(room, 0.0, 1.0)));
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float own = smoothstep(threshold, mix(threshold, 1.0, 0.5) + 0.02, mx);
	w = max(w, own * smoothstep(0.0005, 0.01, s) * 0.95);
	vec3 tint = vec3(1.0);
	float dim = clamp(1.0 - g, 0.0, 1.0);
	if (mode == 1) {
		tint = mix(vec3(1.0), vec3(0.9, 1.0, 0.97), dim);
	} else {
		tint = mix(vec3(1.0), vec3(1.0, 0.66, 0.38), clamp(dim * warmth * 1.4, 0.0, 1.0));
	}
	vec3 factor = mix(vec3(1.0), g * tint, w);
	vec3 outc = clamp(rgb * factor, 0.0, 1.0);
	COLOR = vec4(outc * o.a, o.a);
}
