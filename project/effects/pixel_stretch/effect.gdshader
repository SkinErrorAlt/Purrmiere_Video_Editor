shader_type canvas_item;
render_mode blend_disabled;

uniform int direction : hint_range(0, 3) = 0;
uniform float position : hint_range(0.0, 1.0) = 0.5;
uniform float start : hint_range(0.0, 1.0) = 0.5;
uniform float jitter : hint_range(0.0, 50.0) = 0.0;
uniform float jitter_speed : hint_range(0.0, 30.0) = 8.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float noise1(float x, float salt, vec2 so) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash12(vec2(i, salt) + so), hash12(vec2(i + 1.0, salt) + so), f);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec2 so = seed_offset(seed);
	float t = max(clip_time, 0.0) * jitter_speed;
	float wob = 0.0;
	if (jitter > 0.0) {
		float n = noise1(t, 1.0, so) - 0.5 + (hash12(vec2(mod(floor(t * 2.0), 4099.0), 2.0) + so) - 0.5) * 0.5;
		wob = n * 2.0 * jitter * px_scale;
	}
	bool vertical = direction <= 1;
	float along = vertical ? UV.y : UV.x;
	bool inside = (direction == 0 || direction == 2) ? along >= start : along <= start;
	vec2 uv = UV;
	if (inside) {
		float src = clamp(position + wob / (vertical ? dims.y : dims.x), 0.0, 1.0);
		if (vertical) {
			uv.y = src;
		} else {
			uv.x = src;
		}
	}
	COLOR = texture(TEXTURE, uv);
}
