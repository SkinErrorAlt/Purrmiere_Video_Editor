shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int ghosts : hint_range(1, 8) = 6;
uniform float spread : hint_range(0.2, 2.0) = 1.0;
uniform float size : hint_range(0.01, 0.25) = 0.06;
uniform int blades : hint_range(0, 9) = 6;
uniform float blade_turn : hint_range(-180.0, 180.0) = 15.0;
uniform int style = 0;
uniform float rainbow : hint_range(0.0, 1.0) = 0.5;

const float GOLDEN = 2.39996323;

float ghost_k(int i) {
	if (i == 0) { return -0.55; }
	if (i == 1) { return -1.0; }
	if (i == 2) { return -0.3; }
	if (i == 3) { return 0.45; }
	if (i == 4) { return -1.5; }
	if (i == 5) { return -0.8; }
	if (i == 6) { return 0.7; }
	return -1.25;
}

float ghost_size(int i) {
	if (i == 0) { return 1.0; }
	if (i == 1) { return 0.7; }
	if (i == 2) { return 0.45; }
	if (i == 3) { return 0.6; }
	if (i == 4) { return 1.6; }
	if (i == 5) { return 0.8; }
	if (i == 6) { return 0.35; }
	return 1.2;
}

vec4 ghost_tone(int i) {
	if (i == 0) { return vec4(1.0, 0.84, 0.58, 0.9); }
	if (i == 1) { return vec4(0.58, 0.86, 1.0, 0.7); }
	if (i == 2) { return vec4(0.76, 1.0, 0.62, 0.8); }
	if (i == 3) { return vec4(1.0, 0.64, 0.86, 0.5); }
	if (i == 4) { return vec4(0.92, 0.94, 1.0, 0.45); }
	if (i == 5) { return vec4(0.62, 0.72, 1.0, 0.6); }
	if (i == 6) { return vec4(1.0, 0.76, 0.5, 0.6); }
	return vec4(0.72, 1.0, 0.9, 0.4);
}

float iris(float theta) {
	if (blades < 3) {
		return 1.0;
	}
	float seg = 6.28318530718 / float(blades);
	float a = mod(theta - radians(blade_turn), seg) - seg * 0.5;
	return cos(seg * 0.5) / max(cos(a), 0.0001);
}

vec3 fetch(sampler2D tex, vec2 s, float aspect) {
	vec2 uv = s / vec2(aspect, 1.0) + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return texture(tex, uv).rgb;
}

float edge(float q, float soft) {
	return 1.0 - smoothstep(1.0 - soft, 1.0 + soft * 0.25, q);
}

float ring_shape(float q) {
	return 0.22 + 0.78 * smoothstep(0.5, 0.94, q);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 x = (UV - 0.5) * vec2(aspect, 1.0);
	float e = clamp(rainbow, 0.0, 1.0) * 0.14;
	float soft = 0.14;
	vec3 total = vec3(0.0);
	int count = clamp(ghosts, 1, 8);
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		float k = ghost_k(i) * spread;
		float r = max(size, 0.001) * ghost_size(i);
		float rmax = r * (1.0 + e) * (1.0 + soft * 0.3);
		float src_r = rmax / abs(k) * tex_size.y;
		int n = int(clamp(3.14159 * src_r * src_r / 1.2, 24.0, 160.0));
		vec3 acc = vec3(0.0);
		vec3 wsum = vec3(0.0);
		for (int j = 0; j < 160; j++) {
			if (j >= n) {
				break;
			}
			float rr = sqrt((float(j) + 0.5) / float(n));
			float th = float(j) * GOLDEN;
			vec2 o = vec2(cos(th), sin(th)) * rr * rmax;
			float q = rr * rmax / (r * iris(th));
			vec3 w = vec3(edge(q / (1.0 + e), soft), edge(q, soft), edge(q / (1.0 - e), soft));
			vec3 b = fetch(TEXTURE, (x + o) / k, aspect);
			if (style == 1) {
				b *= vec3(ring_shape(q / (1.0 + e)), ring_shape(q), ring_shape(q / (1.0 - e)));
			}
			acc += b * w;
			wsum += w;
		}
		vec4 tone = ghost_tone(i);
		vec3 v = acc / max(wsum, vec3(0.0001));
		total += (1.0 - exp(-v * 14.0)) * 0.4 * tone.rgb * tone.a;
	}
	vec3 enc = sqrt(clamp(total * 0.25, 0.0, 1.0));
	enc += (hash12(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(clamp(enc, 0.0, 1.0), 1.0);
}
