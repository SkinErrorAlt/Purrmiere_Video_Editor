shader_type canvas_item;
render_mode blend_disabled;

uniform float smear : hint_range(0.0, 400.0) = 50.0;
uniform float block_size : hint_range(4.0, 96.0) = 16.0;
uniform float direction : hint_range(-180.0, 180.0) = 0.0;
uniform float swirl : hint_range(0.0, 1.0) = 0.6;
uniform float blockiness : hint_range(0.0, 1.0) = 0.75;
uniform float speed : hint_range(0.0, 4.0) = 0.4;
uniform float build_up : hint_range(0.0, 10.0) = 0.8;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 512.0);
	float a = hash12(w);
	float b = hash12(w + vec2(1.0, 0.0));
	float c = hash12(w + vec2(0.0, 1.0));
	float d = hash12(w + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 flow(vec2 p, float bs, float base_angle, float tt, vec2 sk) {
	vec2 cell = floor(p / bs);
	vec2 q = mix(p, (cell + 0.5) * bs, clamp(blockiness, 0.0, 1.0));
	float n = value_noise(q / (bs * 7.0) + vec2(tt, tt * 0.61) + sk);
	float n2 = value_noise(q / (bs * 3.0) - vec2(tt * 0.7, tt * 0.33) + sk * 1.7);
	float jitter = hash12(mod(cell, 1024.0) + sk) - 0.5;
	float sw = clamp(swirl, 0.0, 1.0);
	float ang = base_angle + (n - 0.5) * 6.2831853 * sw * 1.3 + (n2 - 0.5) * 2.4 * sw + jitter * 2.2 * sw * blockiness;
	float mag = mix(1.0, 0.35 + 1.3 * hash12(mod(cell, 1024.0) + sk + 19.0), clamp(blockiness, 0.0, 1.0) * 0.8);
	return vec2(cos(ang), sin(ang)) * mag;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float bs = max(block_size * ps, 2.0);
	float grow = build_up > 0.0001 ? clamp(max(clip_time, 0.0) / build_up, 0.0, 1.0) : 1.0;
	grow = grow * grow * (3.0 - 2.0 * grow);
	float len = max(smear, 0.0) * ps * grow;
	vec2 pix = UV * size;
	vec4 here = texture(TEXTURE, UV);
	if (len < 0.05) {
		COLOR = here;
	} else {
		vec2 sk = vec2(mod(float(seed), 997.0) * 0.731 + 3.0, mod(float(seed), 991.0) * 0.419 + 7.0);
		float tt = clip_time * speed;
		float base_angle = radians(direction);
		float step_len = len / 12.0;
		vec2 p = pix;
		vec2 centre_px = (floor(pix / bs) + 0.5) * bs;
		vec2 cp = centre_px;
		for (int i = 0; i < 12; i++) {
			p -= flow(p, bs, base_angle, tt, sk) * step_len;
			cp -= flow(cp, bs, base_angle, tt, sk) * step_len;
		}
		vec2 shift = mix(p - pix, cp - centre_px, clamp(blockiness, 0.0, 1.0) * 0.85);
		vec4 trail = vec4(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 8; i++) {
			float f = float(i + 1) / 8.0;
			float w = f * f;
			trail += texture(TEXTURE, clamp((pix + shift * f) / size, vec2(0.0), vec2(1.0))) * w;
			wsum += w;
		}
		vec4 far = texture(TEXTURE, clamp((pix + shift) / size, vec2(0.0), vec2(1.0)));
		vec4 moshed = mix(trail / max(wsum, 0.0001), far, 0.55);
		vec2 cell = floor(pix / bs);
		float keep = step(0.93, hash12(mod(cell, 1024.0) + sk + floor(tt * 3.0)));
		COLOR = mix(moshed, here, keep * 0.5 * (1.0 - grow * 0.5));
	}
}
