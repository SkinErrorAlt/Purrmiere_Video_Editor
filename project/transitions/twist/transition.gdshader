shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float twist_amount : hint_range(0.0, 360.0) = 45.0;
uniform float twist_length : hint_range(0.05, 1.0) = 1.0;
uniform float stretch : hint_range(0.0, 1.0) = 0.1;
uniform float stagger : hint_range(0.0, 0.8) = 0.05;
uniform int turns = 0;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float twist_angle(float an, float p) {
	float a = clamp(an, 0.0, 1.0);
	float total = TR_PI * (1.0 + 2.0 * float(turns));
	float amount = radians(twist_amount);
	float local_t = clamp((p - stagger * a) / max(1.0 - stagger, 0.0001), 0.0, 1.0);
	float k = clamp(a / max(twist_length, 0.0001), 0.0, 1.0);
	float lag = amount * k * k * (3.0 - 2.0 * k);
	return clamp((total + amount) * tr_ease(local_t, 3) - lag, 0.0, total);
}

vec2 to_world(vec2 ab, bool vertical, bool reverse) {
	float a = reverse ? -ab.x : ab.x;
	return vertical ? vec2(ab.y, -a) : vec2(a, ab.y);
}

float ribbon_f(float z, vec2 ab, float d, float grow, float len, float p, out float th) {
	float k = (d + z) / d;
	th = twist_angle(ab.x * k / grow / len + 0.5, p);
	return ab.y * k * sin(th) - z * cos(th);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	bool vertical = direction >= 2;
	bool reverse = direction == 1 || direction == 3;
	vec2 w = tr_world(uv);
	vec2 ab = vertical ? vec2(-w.y, w.x) : w;
	if (reverse) {
		ab.x = -ab.x;
	}
	float len = vertical ? 1.0 : tr_ratio();
	float half_b = vertical ? tr_ratio() * 0.5 : 0.5;
	float grow = 1.0 + stretch * sin(TR_PI * tr_ease(p, 3));
	float d = tr_camera_distance(lens);
	float z_near = max(-half_b, -d * 0.95);
	float z_far = half_b;
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	float th = 0.0;
	float z0 = z_near;
	float f0 = ribbon_f(z0, ab, d, grow, len, p, th);
	for (int i = 1; i <= 48; i++) {
		float z1 = mix(z_near, z_far, float(i) / 48.0);
		float f1 = ribbon_f(z1, ab, d, grow, len, p, th);
		if (f0 == 0.0 || f0 * f1 < 0.0) {
			float lo = z0;
			float hi = z1;
			float flo = f0;
			for (int j = 0; j < 10; j++) {
				float mid = 0.5 * (lo + hi);
				float fm = ribbon_f(mid, ab, d, grow, len, p, th);
				if (flo * fm <= 0.0) {
					hi = mid;
				} else {
					lo = mid;
					flo = fm;
				}
			}
			float z = 0.5 * (lo + hi);
			ribbon_f(z, ab, d, grow, len, p, th);
			float k = (d + z) / d;
			float b = ab.y * k;
			float s = b * cos(th) + z * sin(th);
			float ap = ab.x * k / grow;
			float an = ap / len + 0.5;
			if (abs(s) <= half_b && an >= 0.0 && an <= 1.0) {
				bool front = cos(th) - ab.y * sin(th) / d > 0.0;
				vec2 sw = front ? vec2(ap, s) : vec2(ap, -s);
				vec2 cuv = tr_frame_uv(to_world(sw, vertical, reverse));
				vec4 c = front ? from_at(cuv) : to_at(cuv);
				float light = mix(1.0, abs(cos(th)), shading);
				res = tr_over(tr_shade(c, light), bg);
				break;
			}
		}
		z0 = z1;
		f0 = f1;
	}
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
