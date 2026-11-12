shader_type canvas_item;
render_mode blend_disabled;

uniform int copies : hint_range(2, 24) = 6;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float start_angle : hint_range(-180.0, 180.0) = 0.0;
uniform float twist : hint_range(-90.0, 90.0) = 0.0;
uniform float scale_step : hint_range(0.6, 1.4) = 1.0;
uniform float opacity : hint_range(0.2, 1.0) = 0.82;
uniform float spin : hint_range(-180.0, 180.0) = 0.0;
uniform int blend : hint_range(0, 3) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec4 sample_copy(sampler2D tex, vec2 uv, float ar, float ang, float sc) {
	vec2 d = uv - centre;
	vec2 da = vec2(d.x * ar, d.y);
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 r = vec2(da.x * cs + da.y * sn, -da.x * sn + da.y * cs) / max(sc, 0.01);
	vec2 suv = centre + vec2(r.x / ar, r.y);
	if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, suv);
}

void fragment() {
	float ar = tex_size.x / max(tex_size.y, 1.0);
	float t = clip_time;
	int n = clamp(copies, 1, 24);
	float base = 360.0 / float(n);
	vec4 over_acc = vec4(0.0);
	vec3 add_acc = vec3(0.0);
	vec4 blend_acc = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 24; i++) {
		if (i >= n) {
			break;
		}
		float ang = radians(start_angle + spin * t + float(i) * base + float(i) * twist);
		float sc = pow(scale_step, float(i));
		vec4 s = sample_copy(TEXTURE, UV, ar, ang, sc);
		float op = pow(clamp(opacity, 0.0, 1.0), float(i));
		blend_acc += s * op;
		wsum += op;
		vec4 so = s * op;
		over_acc += so * (1.0 - over_acc.a);
		add_acc += so.rgb;
	}
	vec4 mand;
	if (blend == 0) {
		mand = blend_acc / max(wsum, 0.0001);
	} else if (blend == 1) {
		mand = over_acc;
	} else if (blend == 2) {
		mand = vec4(min(add_acc, vec3(1.0)), 1.0);
	} else {
		mand = vec4(1.0 - exp(-add_acc), 1.0);
	}
	vec4 orig = texture(TEXTURE, UV);
	COLOR = mix(orig, mand, clamp(strength, 0.0, 1.0));
}
