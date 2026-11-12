shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float threshold : hint_range(0.0, 1.0) = 0.75;
uniform vec4 practical_colour : source_color = vec4(1.0, 0.72, 0.42, 1.0);
uniform vec4 ambient_colour : source_color = vec4(0.55, 0.72, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.7;
uniform float warm_reach : hint_range(0.0, 1.0) = 0.5;
uniform bool keep_brightness = true;
uniform bool show_light = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

float smooth_sample(sampler2D tex, vec2 uv) {
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
	float s0 = texture(tex, off.xz).r;
	float s1 = texture(tex, off.yz).r;
	float s2 = texture(tex, off.xw).r;
	float s3 = texture(tex, off.yw).r;
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	float r = mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
	return r * r;
}

vec3 balanced(vec3 c) {
	return c / max(dot(c, LUMA), 0.02);
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec3 rgb = o.a > 0.0001 ? o.rgb / o.a : vec3(0.0);
	float s = smooth_sample(TEXTURE, UV);
	float k = mix(20.0, 900.0, clamp(warm_reach, 0.0, 1.0));
	float p = s * k / (s * k + 1.0);
	vec3 mx = rgb;
	float own = smoothstep(threshold, mix(threshold, 1.0, 0.5) + 0.02, max(mx.r, max(mx.g, mx.b)));
	p = max(p, own * smoothstep(0.0002, 0.004, s));
	vec3 warm = balanced(clamp(practical_colour.rgb, 0.02, 1.0));
	vec3 cool = balanced(clamp(ambient_colour.rgb, 0.02, 1.0));
	vec3 tint = mix(cool, warm, p);
	vec3 graded = rgb * tint;
	if (keep_brightness) {
		float before = dot(rgb, LUMA);
		float after = dot(graded, LUMA);
		graded *= before / max(after, 0.0001);
	}
	vec3 outc = mix(rgb, graded, clamp(strength, 0.0, 1.0));
	if (show_light) {
		outc = vec3(p);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * o.a, o.a);
}
