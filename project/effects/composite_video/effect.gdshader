shader_type canvas_item;
render_mode blend_disabled;

uniform int system : hint_range(0, 1) = 0;
uniform float dot_crawl : hint_range(0.0, 2.0) = 1.0;
uniform float cross_colour : hint_range(0.0, 2.0) = 0.7;
uniform float ringing : hint_range(0.0, 1.0) = 0.35;
uniform float colour_delay : hint_range(-12.0, 12.0) = 2.5;
uniform float colour_blur : hint_range(0.0, 30.0) = 4.0;
uniform float noise : hint_range(0.0, 1.0) = 0.15;
uniform bool moving = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float seq_fps = 30.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 h22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float vn1(float x, float row) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(h12(vec2(i, row)), h12(vec2(i + 1.0, row)), f);
}

vec3 enc(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	if (system == 1) {
		return vec3(y, 0.492 * (c.b - y), 0.877 * (c.r - y));
	}
	return vec3(y, dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 dec(vec3 k) {
	if (system == 1) {
		return vec3(k.x + 1.140 * k.z, k.x - 0.395 * k.y - 0.581 * k.z, k.x + 2.032 * k.y);
	}
	return vec3(k.x + 0.956 * k.y + 0.621 * k.z, k.x - 0.272 * k.y - 0.647 * k.z, k.x - 1.106 * k.y + 1.703 * k.z);
}

vec3 at(sampler2D tex, float x, float uvy, float sx) {
	return enc(texture(tex, vec2(clamp(x / sx, 0.0, 1.0), uvy)).rgb);
}

float phase(float x, float line, float pd, float fr) {
	float lp = system == 1 ? 1.5 : 1.0;
	float fp = system == 1 ? 1.5 : 0.5;
	return TAU * x / pd + 3.14159265 * (lp * line + fp * fr);
}

vec3 carrier(sampler2D tex, float x, float uvy, float line, float pd, float fr, float sx) {
	float sw = system == 1 ? (mod(line, 2.0) < 1.0 ? 1.0 : -1.0) : 1.0;
	float leak = 0.0;
	float ca = 0.0;
	float cb = 0.0;
	float ws = 0.0;
	for (int i = 0; i < 16; i++) {
		float o = (float(i) - 7.5) / 8.0;
		float w = 1.0 - abs(float(i) - 7.5) / 8.0;
		float xi = x + o * pd;
		vec3 k = at(tex, xi, uvy, sx);
		float ph = phase(xi, line, pd, fr);
		float cs = cos(ph);
		float sn = sin(ph) * sw;
		leak += w * (k.y * cs + k.z * sn);
		ca += w * k.x * cs;
		cb += w * k.x * sn;
		ws += w;
	}
	return vec3(leak, 2.0 * ca, 2.0 * cb) / ws;
}

vec2 chroma(sampler2D tex, float x, float uvy, float sx) {
	float sig = max(colour_blur, 0.05);
	float stp = max(sig * 0.55, 0.3);
	vec2 acc = vec2(0.0);
	float ws = 0.0;
	for (int k = -4; k <= 4; k++) {
		float o = float(k) * stp;
		float w = exp(-0.5 * (o / sig) * (o / sig));
		acc += w * at(tex, x - colour_delay + o, uvy, sx).yz;
		ws += w;
	}
	return acc / ws;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	float x = UV.x * S.x;
	float line = floor(UV.y * S.y);
	float pd = max(S.x / 188.0, 3.0);
	float frn = floor(time * max(seq_fps, 1.0) + 0.001);
	float fr = moving ? frn : 0.0;
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 97.0), mod(fs * 78.233, 91.0));
	vec4 c0 = texture(TEXTURE, UV);
	float a = c0.a;
	float sy = 0.16 * pd;
	float ysoft = 0.0;
	float yw = 0.0;
	for (int k = -2; k <= 2; k++) {
		float o = float(k) * sy * 0.8;
		float w = exp(-0.5 * float(k * k) * 0.64);
		ysoft += w * at(TEXTURE, x + o, UV.y, S.x).x;
		yw += w;
	}
	ysoft /= yw;
	float lam = 0.9 * pd;
	float dl = lam / 6.0;
	float ring = 0.0;
	float prev = at(TEXTURE, x - dl, UV.y, S.x).x;
	for (int k = 1; k <= 12; k++) {
		float nxt = at(TEXTURE, x - float(k + 1) * dl, UV.y, S.x).x;
		float o = float(k) * dl;
		ring += exp(-o / (0.9 * pd)) * sin(TAU * o / lam) * (prev - nxt);
		prev = nxt;
	}
	vec3 car = carrier(TEXTURE, x, UV.y, line, pd, fr, S.x);
	vec2 ch = chroma(TEXTURE, x, UV.y, S.x) + cross_colour * car.yz;
	if (system == 1) {
		float uvy2 = max(UV.y - 1.0 / S.y, 0.0);
		vec3 car2 = carrier(TEXTURE, x, uvy2, line - 1.0, pd, fr, S.x);
		vec2 ch2 = chroma(TEXTURE, x, uvy2, S.x) + cross_colour * car2.yz;
		ch = 0.5 * (ch + ch2);
	}
	vec2 fo = h22(vec2(frn, 3.7) + so) * 900.0;
	float nk = clamp(noise, 0.0, 1.0);
	float white = h12(vec2(floor(x * ps), line) + fo) - 0.5;
	float soft = vn1(x / 1.6 + fo.x, line + fo.y) - 0.5;
	float yn = (white * 0.7 + soft * 1.1) * 0.09 * nk;
	vec2 cn = vec2(vn1(x / (pd * 0.9) + fo.y, line + fo.x + 0.5), vn1(x / (pd * 0.9) + fo.x + 31.0, line + fo.y + 0.5)) - 0.5;
	ch += cn * 0.22 * nk;
	float y = ysoft + dot_crawl * 1.6 * car.x + ringing * 1.6 * ring + yn;
	vec3 rgb = dec(vec3(y, ch));
	COLOR = vec4(min(clamp(rgb, 0.0, 1.0), vec3(a)), a);
}
