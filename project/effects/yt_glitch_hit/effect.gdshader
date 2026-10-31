shader_type canvas_item;
render_mode blend_disabled;

uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.05, 3.0) = 0.4;
uniform float repeat_every : hint_range(0.0, 10.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float band : hint_range(2.0, 120.0) = 22.0;
uniform float tear : hint_range(0.0, 400.0) = 90.0;
uniform float split : hint_range(0.0, 60.0) = 12.0;
uniform float blocks : hint_range(0.0, 1.0) = 0.35;
uniform float rate : hint_range(1.0, 60.0) = 20.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec2 mirror(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

void fragment() {
	float dt = clip_time - starts_at;
	if (repeat_every > 0.001 && dt >= 0.0) {
		dt = mod(dt, repeat_every);
	}
	float env = 0.0;
	if (dt >= 0.0 && dt <= duration) {
		float f = dt / max(duration, 0.001);
		env = (1.0 - f * f) * clamp(strength, 0.0, 1.0);
	}
	if (env <= 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 size = max(tex_size, vec2(1.0));
		float st = floor(dt * rate);
		float sd = float(seed);
		float bh = max(band * px_scale, 1.0) / size.y;
		float row = floor(UV.y / bh);
		float h = hash(vec3(row, st, sd));
		vec2 uv = UV;
		if (h < 0.45 * env) {
			uv.x += (hash(vec3(row, st, sd + 7.0)) - 0.5) * 2.0 * tear * px_scale * env / size.x;
		}
		vec2 cell = floor(UV * size / max(band * px_scale * 3.0, 2.0));
		float hb = hash(vec3(cell, st + sd * 3.1));
		bool flip = hb < blocks * env * 0.5;
		if (flip) {
			uv += (vec2(hash(vec3(cell, st + 1.0)), hash(vec3(cell, st + 2.0))) - 0.5) * 0.08 * env;
		}
		vec2 off = vec2(split * px_scale * env / size.x, 0.0);
		vec4 r = texture(TEXTURE, mirror(uv + off));
		vec4 g = texture(TEXTURE, mirror(uv));
		vec4 b = texture(TEXTURE, mirror(uv - off));
		float al = max(max(r.a, g.a), b.a);
		vec3 rgb = min(vec3(r.r, g.g, b.b), vec3(al));
		if (flip) {
			rgb = vec3(al) - rgb;
			rgb = rgb.gbr;
		}
		COLOR = vec4(rgb, al);
	}
}
