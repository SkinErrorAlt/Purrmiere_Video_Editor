shader_type canvas_item;
render_mode blend_disabled;

uniform float length_amount : hint_range(0.0, 0.2) = 0.035;
uniform float scale : hint_range(0.5, 16.0) = 4.0;
uniform float follow : hint_range(0.0, 1.0) = 0.35;
uniform float churn : hint_range(-2.0, 2.0) = 0.0;
uniform int taps : hint_range(2, 16) = 9;
uniform float keep_edges : hint_range(0.0, 1.0) = 0.25;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;

float cs_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = cs_hash(i);
	float b = cs_hash(i + vec2(1.0, 0.0));
	float c = cs_hash(i + vec2(0.0, 1.0));
	float d = cs_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float cs_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * cs_noise(p);
		p = p * 2.07 + vec2(11.3, 5.1);
		a *= 0.5;
	}
	return v;
}

vec2 flow_at(sampler2D tex, vec2 uv, float t) {
	float e = 0.004;
	float n1 = cs_fbm(uv * scale + vec2(t, -t * 0.7));
	float nx = cs_fbm((uv + vec2(e, 0.0)) * scale + vec2(t, -t * 0.7)) - n1;
	float ny = cs_fbm((uv + vec2(0.0, e)) * scale + vec2(t, -t * 0.7)) - n1;
	vec2 curl = vec2(ny, -nx);
	if (follow > 0.0) {
		vec2 s = vec2(2.0) / max(tex_size, vec2(1.0));
		float lx = dot(texture(tex, clamp(uv + vec2(s.x, 0.0), vec2(0.0), vec2(1.0))).rgb - texture(tex, clamp(uv - vec2(s.x, 0.0), vec2(0.0), vec2(1.0))).rgb, vec3(0.333));
		float ly = dot(texture(tex, clamp(uv + vec2(0.0, s.y), vec2(0.0), vec2(1.0))).rgb - texture(tex, clamp(uv - vec2(0.0, s.y), vec2(0.0), vec2(1.0))).rgb, vec3(0.333));
		vec2 along = vec2(-ly, lx);
		curl = mix(curl, along * 0.02, clamp(follow, 0.0, 1.0));
	}
	float len = length(curl);
	return len > 0.000001 ? curl / len : vec2(1.0, 0.0);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0 || length_amount <= 0.0) {
		COLOR = base;
	} else {
		float t = clip_time * churn;
		int n = clamp(taps, 2, 16);
		vec4 acc = vec4(0.0);
		float total = 0.0;
		vec2 at = UV;
		for (int i = 0; i < 16; i++) {
			if (i >= n) {
				break;
			}
			float f = float(i) / float(max(n - 1, 1)) - 0.5;
			vec2 dir = flow_at(TEXTURE, clamp(at, vec2(0.0), vec2(1.0)), t);
			vec2 sample_at = clamp(UV + dir * length_amount * f, vec2(0.0), vec2(1.0));
			float w = 1.0 - abs(f) * 1.2;
			w = max(w, 0.05);
			acc += texture(TEXTURE, sample_at) * w;
			total += w;
			at = sample_at;
		}
		vec4 smeared = acc / max(total, 0.0001);
		COLOR = mix(base, mix(smeared, base, clamp(keep_edges, 0.0, 1.0) * 0.6), strength);
	}
}
