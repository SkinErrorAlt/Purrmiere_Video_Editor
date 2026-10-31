shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float spread : hint_range(0.0, 100.0) = 14.0;
uniform int mode : hint_range(0, 1) = 1;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);

vec3 spectrum(float h) {
	float r = exp(-pow((h - 0.08) / 0.24, 2.0)) + 0.35 * exp(-pow((h - 1.0) / 0.12, 2.0));
	float g = exp(-pow((h - 0.5) / 0.2, 2.0));
	float b = exp(-pow((h - 0.9) / 0.24, 2.0));
	return vec3(r, g, b);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 offset;
	if (mode == 0) {
		float rad = radians(angle);
		offset = vec2(cos(rad), sin(rad)) * spread * ps;
	} else {
		vec2 d = (UV - centre) * sz;
		float half_diag = 0.5 * length(sz);
		offset = d / max(half_diag, 1.0) * spread * ps;
	}
	float reach = length(offset);
	if (reach < 0.25) {
		COLOR = texture(TEXTURE, UV);
	} else {
		int n = int(clamp(ceil(reach * 1.5), 8.0, 48.0));
		vec3 acc = vec3(0.0);
		vec3 wsum = vec3(0.0);
		float alpha = 0.0;
		for (int i = 0; i < 48; i++) {
			if (i >= n) {
				break;
			}
			float h = (float(i) + 0.5) / float(n);
			float t = h * 2.0 - 1.0;
			vec4 s = texture(TEXTURE, UV + offset * t / sz);
			vec3 w = spectrum(h);
			acc += s.rgb * w;
			wsum += w;
			alpha += s.a;
		}
		vec3 rgb = acc / max(wsum, vec3(0.0001));
		float a = alpha / float(n);
		COLOR = vec4(min(rgb, vec3(a)), a);
	}
}
