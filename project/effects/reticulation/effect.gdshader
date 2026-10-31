shader_type canvas_item;
render_mode blend_disabled;

uniform float density : hint_range(0.0, 50.0) = 12.0;
uniform float foreground_level : hint_range(0.0, 50.0) = 40.0;
uniform float background_level : hint_range(0.0, 50.0) = 5.0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool moving = false;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	if (moving) {
		fs += floor(max(time, 0.0) * 24.0) * 7.0;
	}
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float dn = clamp(density / 50.0, 0.0, 1.0);
	float worm = abs(vn(P / 1.6) - 0.5) * 2.0;
	float clump = vn(P / 2.4) * 0.4 + vn(P / 5.5 + 11.3) * 0.35 + vn(P / 13.0 + 41.7) * 0.25;
	clump = mix(clump, 1.0 - worm, 0.35);
	float speck = h12(floor(P));
	float shadow = 1.0 - l;
	float n = mix(speck, clump, 0.3 + 0.6 * shadow);
	float amp = 0.3 + dn * 1.2;
	float fg = foreground_level / 50.0;
	float bg = background_level / 50.0;
	float t = clamp((l - 0.5) * 1.15 + 0.5, 0.0, 1.0);
	t += ((bg - 0.1) - (fg - 0.8)) * 0.35;
	float v = t + (n - 0.5) * amp;
	float soft = mix(0.2, 0.06, dn);
	float k = smoothstep(0.5 - soft, 0.5 + soft, v);
	vec3 col = mix(ink.rgb, paper.rgb, k);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
