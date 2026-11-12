shader_type canvas_item;
render_mode blend_disabled;

uniform int points : hint_range(0, 2) = 0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform float reach : hint_range(0.01, 0.6) = 0.16;
uniform float threshold : hint_range(0.0, 1.0) = 0.62;
uniform float falloff : hint_range(0.5, 6.0) = 2.2;
uniform float chroma : hint_range(0.0, 1.0) = 0.3;
uniform float glare : hint_range(0.0, 3.0) = 1.1;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);

const float SF_PI = 3.14159265358979;

float sf_lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sf_split(float t) {
	return vec3(1.0 - t * 0.35, 1.0 - abs(t - 0.5) * 0.5, 0.65 + t * 0.35);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		int arms = points == 0 ? 4 : (points == 1 ? 6 : 8);
		float ar = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
		float a0 = radians(angle);
		vec3 rays = vec3(0.0);
		for (int k = 0; k < 8; k++) {
			if (k >= arms) {
				break;
			}
			float a = a0 + float(k) * SF_PI * 2.0 / float(arms);
			vec2 dir = vec2(cos(a) / ar, sin(a));
			for (int s = 1; s <= 14; s++) {
				float f = float(s) / 14.0;
				vec2 at = UV + dir * reach * f;
				if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) {
					break;
				}
				vec3 c = texture(TEXTURE, at).rgb;
				float hot = max(sf_lum(c) - threshold, 0.0) / max(1.0 - threshold, 0.0001);
				float w = pow(1.0 - f, falloff);
				vec3 tintc = mix(vec3(1.0), sf_split(f), chroma);
				rays += c * hot * w * tintc;
			}
		}
		rays *= glare / 4.2;
		vec4 lit = base;
		lit.rgb += rays;
		COLOR = mix(base, lit, strength);
	}
}
