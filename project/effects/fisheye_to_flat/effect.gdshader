shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int direction : hint_range(0, 1) = 0;
uniform int projection : hint_range(0, 3) = 0;
uniform float fov : hint_range(60.0, 220.0) = 130.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float zoom : hint_range(0.3, 3.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int outside : hint_range(0, 1) = 0;

const float HALF_PI = 1.5707963;

float theta_max() {
	float t = radians(clamp(fov, 1.0, 220.0)) * 0.5;
	if (projection == 3) {
		t = min(t, radians(89.0));
	}
	if (projection == 2) {
		t = min(t, radians(170.0));
	}
	return t;
}

float fish_r(float theta) {
	if (projection == 1) {
		return 2.0 * sin(theta * 0.5);
	}
	if (projection == 2) {
		return 2.0 * tan(theta * 0.5);
	}
	if (projection == 3) {
		return sin(min(theta, HALF_PI));
	}
	return theta;
}

float fish_theta(float r) {
	if (projection == 1) {
		return 2.0 * asin(clamp(r * 0.5, 0.0, 1.0));
	}
	if (projection == 2) {
		return 2.0 * atan(r * 0.5);
	}
	if (projection == 3) {
		return asin(clamp(r, 0.0, 1.0));
	}
	return r;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 p = (UV - centre) * size;
	float half_w = size.x * 0.5;
	float f_fish = half_w / max(fish_r(theta_max()), 0.0001);
	float f_flat = f_fish * max(zoom, 0.01);
	float r_out = length(p);
	float r_in = r_out;
	bool beyond = false;
	if (r_out > 0.0001) {
		if (direction == 0) {
			float theta = atan(r_out / f_flat);
			r_in = f_fish * fish_r(theta);
		} else {
			float rn = r_out / f_fish;
			if ((projection == 1 && rn > 2.0) || (projection == 3 && rn > 1.0)) {
				beyond = true;
			}
			float theta = fish_theta(rn);
			if (theta >= radians(89.5)) {
				beyond = true;
				theta = radians(89.5);
			}
			r_in = f_fish / max(zoom, 0.01) * tan(theta);
		}
	}
	float k = r_out > 0.0001 ? r_in / r_out : 1.0 / max(zoom, 0.01);
	vec2 q = p * mix(1.0, k, clamp(strength, 0.0, 1.0));
	vec2 uv = centre + q / size;
	bool out_of = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || (beyond && strength > 0.999);
	if (out_of && outside == 0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	}
}
