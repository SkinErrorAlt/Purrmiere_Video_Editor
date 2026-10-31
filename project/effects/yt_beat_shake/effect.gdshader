shader_type canvas_item;
render_mode blend_disabled;

uniform float bpm : hint_range(30.0, 300.0) = 120.0;
uniform float offset : hint_range(-10.0, 10.0) = 0.0;
uniform int every : hint_range(0, 3) = 0;
uniform float amount : hint_range(0.0, 200.0) = 24.0;
uniform float rotation : hint_range(0.0, 20.0) = 1.5;
uniform float zoom : hint_range(0.0, 30.0) = 4.0;
uniform float decay : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 mirror(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

void fragment() {
	float mul = every == 1 ? 0.5 : (every == 2 ? 0.25 : (every == 3 ? 2.0 : 1.0));
	float beats = (clip_time - offset) * max(bpm, 1.0) / 60.0 * mul;
	vec2 size = max(tex_size, vec2(1.0));
	float asp = size.x / size.y;
	vec2 off = vec2(0.0);
	float ang = 0.0;
	if (beats >= 0.0) {
		float idx = floor(beats);
		float ph = fract(beats);
		float env = exp(-ph * (3.0 + decay * 12.0)) * cos(ph * 15.7);
		float a = hash(vec2(idx, float(seed))) * 6.2831853;
		off = vec2(cos(a), sin(a)) * amount * px_scale * env / size;
		ang = radians(rotation) * env * (hash(vec2(idx + 17.0, float(seed))) < 0.5 ? -1.0 : 1.0);
	}
	vec2 p = UV - 0.5 - off;
	p.x *= asp;
	p = vec2(cos(ang) * p.x - sin(ang) * p.y, sin(ang) * p.x + cos(ang) * p.y);
	p.x /= asp;
	p /= 1.0 + zoom * 0.01;
	COLOR = texture(TEXTURE, mirror(p + 0.5));
}
