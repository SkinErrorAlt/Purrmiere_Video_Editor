shader_type canvas_item;
render_mode blend_disabled;

uniform float signal : hint_range(0.0, 1.0) = 0.62;
uniform float breakup : hint_range(0.0, 1.0) = 0.45;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float camera : hint_range(0.0, 1.0) = 0.5;
uniform float colour_smear : hint_range(0.0, 12.0) = 3.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float n1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash12(vec2(i, 7.0 + float(seed))), hash12(vec2(i + 1.0, 7.0 + float(seed))), f * f * (3.0 - 2.0 * f));
}

vec3 straight(vec4 s) {
	return s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
}

vec3 rgb2yiq(vec3 c) {
	return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 yiq2rgb(vec3 c) {
	return vec3(c.x + 0.956 * c.y + 0.621 * c.z, c.x - 0.272 * c.y - 0.647 * c.z, c.x - 1.106 * c.y + 1.703 * c.z);
}

void fragment() {
	vec4 here = texture(TEXTURE, UV);
	float a = here.a;
	vec2 size = max(tex_size, vec2(1.0));
	float s = max(px_scale, 0.05);
	float tt = time * speed;
	float line_h = max(size.y / 480.0, 1.0);
	float l = floor(UV.y * size.y / line_h);
	float slow = n1(tt * 0.7) * 0.6 + n1(tt * 2.3 + 11.0) * 0.4;
	float burst = smoothstep(0.55, 0.95, n1(tt * 3.1 + 31.0));
	float lw = n1(l / 37.0 + floor(tt * 30.0) * 0.37) * 0.6 + n1(l / 9.0 + floor(tt * 30.0) * 1.7) * 0.4;
	float eff = signal - breakup * (0.45 * slow + 0.4 * burst + 0.25 * lw - 0.3);
	eff = clamp(eff, 0.0, 1.0);
	float fe = clamp(signal - breakup * (0.45 * slow + 0.4 * burst - 0.2), 0.0, 1.0);
	float fid = floor(tt * 30.0);
	vec2 uv = UV;
	float roll = 1.0 - smoothstep(0.06, 0.16, fe);
	uv.y = fract(uv.y + roll * fract(tt * 0.9 + hash12(vec2(fid, 3.0)) * 0.1));
	float tear_amt = 1.0 - smoothstep(0.2, 0.42, eff);
	float tear_band = floor(l / 6.0);
	float tear = (hash12(vec2(tear_band, fid + float(seed))) - 0.5) * tear_amt * tear_amt * 0.12;
	tear *= step(0.6 - tear_amt * 0.4, hash12(vec2(tear_band * 1.7, fid + 3.0)));
	uv.x += tear;
	vec2 px = vec2(1.0) / size;
	float soft = 1.4 * s;
	vec3 c0 = straight(texture(TEXTURE, uv));
	vec3 cl = straight(texture(TEXTURE, uv - vec2(px.x * soft, 0.0)));
	vec3 cr = straight(texture(TEXTURE, uv + vec2(px.x * soft, 0.0)));
	vec3 cu = straight(texture(TEXTURE, uv - vec2(0.0, px.y * soft)));
	vec3 cd = straight(texture(TEXTURE, uv + vec2(0.0, px.y * soft)));
	vec3 blur = (cl + cr + cu + cd) * 0.25;
	vec3 base = (c0 * 2.0 + cl + cr) * 0.25;
	vec3 wide = straight(texture(TEXTURE, uv - vec2(px.x * 3.5 * s, 0.0))) * 0.5 + straight(texture(TEXTURE, uv + vec2(px.x * 3.5 * s, 0.0))) * 0.5;
	base += (base - mix(blur, wide, 0.5)) * camera * 1.6;
	vec3 yiq = rgb2yiq(base);
	float sm = colour_smear * s;
	vec3 ch = vec3(0.0);
	for (int i = 0; i < 5; i++) {
		float o = (float(i) - 1.0) * sm * 0.6 + sm * 0.8;
		ch += rgb2yiq(straight(texture(TEXTURE, uv - vec2(px.x * o, 0.0))));
	}
	ch /= 5.0;
	yiq.yz = ch.yz;
	float sat = smoothstep(0.22, 0.42, eff);
	float killer = step(0.5, hash12(vec2(fid, 17.0 + float(seed))));
	sat *= mix(1.0, killer, 1.0 - smoothstep(0.32, 0.5, eff));
	yiq.yz *= sat;
	float hiss = 1.0 - smoothstep(0.05, 0.85, eff);
	yiq.x += (hash12(UV * size + fid * 13.7) - 0.5) * (0.03 + hiss * 0.12);
	float spark_d = pow(1.0 - smoothstep(0.15, 0.78, eff), 1.6);
	float cell_w = 18.0 * s;
	float cx = floor(UV.x * size.x / cell_w);
	float hk = hash12(vec2(cx, l * 1.31 + fid * 7.0 + float(seed)));
	float start = hash12(vec2(cx + 0.5, l + fid * 3.0)) * 0.6;
	float len = 0.15 + hash12(vec2(cx, l + fid * 5.0 + 9.0)) * 0.85;
	float fx = fract(UV.x * size.x / cell_w);
	float in_streak = step(start, fx) * step(fx, start + len) * step(1.0 - spark_d * 0.35, hk);
	float tail = 1.0 - clamp((fx - start) / max(len, 0.01), 0.0, 1.0);
	float white = step(0.35, hash12(vec2(cx * 2.1, l + fid)));
	float spark_v = mix(-0.6, 1.0, white) * (0.5 + 0.5 * tail);
	yiq.x = mix(yiq.x, yiq.x * 0.3 + spark_v, in_streak * 0.85);
	yiq.y += in_streak * (hash12(vec2(cx, l + 2.0)) - 0.5) * 0.4 * sat;
	vec3 rgb = yiq2rgb(yiq);
	float snow_amt = 1.0 - smoothstep(0.0, 0.2, eff);
	float sn = hash12(vec2(floor(UV.x * size.x / (2.0 * s)), l + fid * 31.0));
	sn = mix(sn, hash12(vec2(floor(UV.x * size.x / (7.0 * s)), l + fid * 19.0)), 0.4);
	rgb = mix(rgb, vec3(sn * 0.9), snow_amt);
	float bar = roll * step(fract(UV.y + roll * fract(tt * 0.9 + hash12(vec2(fid, 3.0)) * 0.1)), 0.07);
	rgb = mix(rgb, vec3(0.02), bar);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
