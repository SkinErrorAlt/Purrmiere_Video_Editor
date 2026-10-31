shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float brush_size : hint_range(1.0, 20.0) = 6.0;
uniform float brush_detail : hint_range(0.0, 10.0) = 8.0;
uniform float texture_amount : hint_range(1.0, 3.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float a = texture(effect_tex, UV).a;
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float bs = max(brush_size, 1.0);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float bands = 3.0 + brush_detail * 1.2;
	float lb = l * bands;
	float lq = (floor(lb) + smoothstep(0.2, 0.8, fract(lb))) / bands;
	rgb *= mix(1.0, lq / max(l, 0.02), (1.0 - brush_detail / 10.0) * 0.6);
	vec2 e = vec2(ps * 3.0) / dims;
	vec3 wl = vec3(0.2126, 0.7152, 0.0722);
	vec4 ex = texture(TEXTURE, UV + vec2(e.x, 0.0)) - texture(TEXTURE, UV - vec2(e.x, 0.0));
	vec4 ey = texture(TEXTURE, UV + vec2(0.0, e.y)) - texture(TEXTURE, UV - vec2(0.0, e.y));
	float edge = smoothstep(0.1, 0.35, length(vec2(dot(ex.rgb, wl), dot(ey.rgb, wl))));
	rgb *= 1.0 - edge * 0.3;
	float ang = (value_noise(pix / (bs * 9.0) + so) - 0.5) * 2.4 + 0.5;
	vec2 dir = vec2(cos(ang), sin(ang));
	float along = dot(pix, dir);
	float across = dot(pix, vec2(-dir.y, dir.x));
	float bristle = value_noise(vec2(along / (bs * 2.5), across / 0.9) + so.yx);
	float clump = value_noise(vec2(along / (bs * 6.0), across / (bs * 0.8)) + so + 9.1);
	float t = texture_amount;
	float dry = smoothstep(0.78 - 0.08 * t, 0.95, bristle * 0.7 + clump * 0.45);
	float dab = value_noise(pix / (bs * 2.2) + so.yx * 0.3);
	rgb *= 1.0 + (bristle - 0.5) * 0.14 * t + (dab - 0.5) * 0.12 * t;
	rgb = mix(rgb, rgb * 0.5 + 0.5, dry * 0.45 * min(t, 2.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
