shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int from_shape : hint_range(0, 5) = 0;
uniform int to_shape : hint_range(0, 5) = 1;
uniform float ring : hint_range(0.0, 40.0) = 8.0;
uniform vec4 ring_colour : source_color = vec4(1.0, 0.55, 0.72, 1.0);
uniform float spin : hint_range(-720.0, 720.0) = 90.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

float sde(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

float heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return length(p - vec2(0.25, 0.75)) - 0.353553;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

float star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809017, -0.587785);
	vec2 k2 = vec2(-0.809017, -0.587785);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float tri_ear(vec2 p, vec2 at, float w, float h) {
	vec2 q = p - at;
	float y = -q.y;
	float side = (abs(q.x) - w * (1.0 - y / h)) * h / sqrt(h * h + w * w);
	return max(-y, max(side, y - h));
}

float shape(int k, vec2 p) {
	if (k == 1) {
		return heart(vec2(p.x, -p.y) * 0.75 + vec2(0.0, 0.45)) / 0.75;
	}
	if (k == 2) {
		return star5(vec2(p.x, -p.y), 1.0, 0.45);
	}
	if (k == 3) {
		vec2 q = p * 0.85;
		float d = sde(q - vec2(0.0, 0.2), vec2(0.42, 0.34));
		d = min(d, sde(q - vec2(-0.5, -0.24), vec2(0.15, 0.19)));
		d = min(d, sde(q - vec2(-0.18, -0.52), vec2(0.16, 0.2)));
		d = min(d, sde(q - vec2(0.18, -0.52), vec2(0.16, 0.2)));
		d = min(d, sde(q - vec2(0.5, -0.24), vec2(0.15, 0.19)));
		return d / 0.85;
	}
	if (k == 4) {
		float d = sde(p - vec2(0.0, 0.12), vec2(0.88, 0.76));
		d = min(d, tri_ear(p, vec2(-0.5, -0.35), 0.32, 0.6));
		d = min(d, tri_ear(p, vec2(0.5, -0.35), 0.32, 0.6));
		return d;
	}
	if (k == 5) {
		return (abs(p.x) + abs(p.y) - 1.0) * 0.7071;
	}
	return length(p) - 1.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float R = max(pow(1.0 - pg, 1.8) * 2.6, 0.00001);
	vec2 p = rot(radians(spin) * pg) * q / R;
	float m = smoothstep(0.15, 0.85, pg);
	float d = mix(shape(from_shape, p), shape(to_shape, p), m) * R;
	float px = px_scale / max(tex_size.y, 1.0);
	float dp = d / px;
	float keep = smoothstep(1.0, -1.0, dp);
	float rg = smoothstep(1.0, -1.0, dp - ring) * (1.0 - keep) * step(0.01, ring);
	vec4 o = c * keep + vec4(ring_colour.rgb, 1.0) * ring_colour.a * rg;
	COLOR = pg <= 0.0 ? c : o * (1.0 - smoothstep(0.97, 1.0, pg));
}
