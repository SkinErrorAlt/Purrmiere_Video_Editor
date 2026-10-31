shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_angle : hint_range(-180.0, 180.0) = 150.0;
uniform float shadow_distance : hint_range(0.0, 100.0) = 8.0;
uniform float shadow_softness : hint_range(0.0, 60.0) = 10.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.15;

float shape_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).r;
}

float cut(float m) {
	float w = max(fwidth(m), 0.02);
	return smoothstep(0.5 - w, 0.5 + w, m);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float k = max(px_scale, 0.0001);
	float card = cut(shape_at(TEXTURE, UV));
	float ang = radians(shadow_angle);
	vec2 off = vec2(sin(ang), -cos(ang)) * shadow_distance * k / size;
	float r = shadow_softness * k;
	float spin = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) * 6.28318530718;
	float s = cut(shape_at(TEXTURE, UV - off)) * 2.0;
	float n = 2.0;
	if (r > 0.5) {
		for (int i = 0; i < 24; i++) {
			float fi = float(i) + 0.5;
			float rr = sqrt(fi / 24.0) * r;
			float ga = fi * 2.39996323 + spin;
			s += cut(shape_at(TEXTURE, UV - off + vec2(cos(ga), sin(ga)) * rr / size));
			n += 1.0;
		}
	}
	float sh = clamp(s / n * shadow, 0.0, 1.0);
	float diag = (UV.x * size.x + UV.y * size.y) / max(size.x + size.y, 1.0);
	float gloss = sheen * (exp(-pow(diag - 0.32, 2.0) / 0.0016) * 0.7 + exp(-pow(diag - 0.4, 2.0) / 0.0004) * 0.5);
	vec4 card_c = vec4(colour.rgb * card * colour.a, card * colour.a);
	vec4 shadow_c = vec4(vec3(0.0), sh * (1.0 - card_c.a));
	vec4 pic = texture(effect_tex, UV);
	vec4 o = card_c + shadow_c;
	o = pic + o * (1.0 - pic.a);
	float on_card = max(card * colour.a, pic.a);
	o.rgb = mix(o.rgb, vec3(o.a), clamp(gloss * on_card, 0.0, 1.0));
	COLOR = clamp(o, 0.0, 1.0);
}
