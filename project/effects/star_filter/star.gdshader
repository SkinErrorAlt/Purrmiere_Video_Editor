shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int points : hint_range(0, 2) = 0;
uniform float star_length : hint_range(10.0, 800.0) = 180.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform float rainbow : hint_range(0.0, 1.0) = 0.3;

const int TAPS = 28;

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	int axes = points == 0 ? 2 : (points == 1 ? 3 : 4);
	float reach = max(star_length, 1.0) * ps;
	vec4 core = texture(TEXTURE, UV);
	vec3 rays = vec3(0.0);
	float ray_a = 0.0;
	for (int a = 0; a < 4; a++) {
		if (a >= axes) {
			break;
		}
		float th = radians(angle) + float(a) * 3.1415926 / float(axes);
		vec2 dir = vec2(sin(th), -cos(th));
		vec2 stp = dir * reach / float(TAPS) / sz;
		vec3 best = vec3(0.0);
		float best_a = 0.0;
		for (int i = 1; i <= TAPS; i++) {
			float f = float(i) / float(TAPS);
			float w = pow(1.0 - f, 1.25);
			vec3 hue = 0.5 + 0.5 * cos(6.2831853 * (f * 1.3 + vec3(0.0, 0.33, 0.67)));
			vec3 tintc = mix(vec3(1.0), hue * 1.4, clamp(rainbow, 0.0, 1.0) * smoothstep(0.05, 0.4, f));
			vec4 s1 = texture(TEXTURE, UV + stp * float(i));
			vec4 s2 = texture(TEXTURE, UV - stp * float(i));
			best = max(best, max(s1.rgb, s2.rgb) * tintc * w);
			best_a = max(best_a, max(s1.a, s2.a) * w);
		}
		rays += best;
		ray_a = max(ray_a, best_a);
	}
	COLOR = vec4(rays * 2.2 + core.rgb * 0.5, max(ray_a, core.a));
}
