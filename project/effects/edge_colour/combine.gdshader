shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float width : hint_range(0.5, 50.0) = 4.0;
uniform float pull : hint_range(0.0, 1.0) = 0.6;
uniform float desaturate : hint_range(0.0, 1.0) = 0.6;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool show_band = false;

const float DMAX = 256.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

float inside_at(sampler2D tex, vec2 uv) {
	return unpack16(texture(tex, clamp(uv, vec2(0.0), vec2(1.0))).ba);
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	float k = max(px_scale, 0.0001);
	vec2 size = max(tex_size, vec2(1.0));
	vec4 orig = texture(effect_tex, UV);
	float a = orig.a;
	float d_in = inside_at(TEXTURE, UV);
	float w_px = max(width, 0.5) * k;
	float r = clamp(d_in / w_px, 0.0, 1.0);
	float band = a > 0.001 ? 1.0 - r * r : 0.0;
	vec3 rgb = straight(orig);
	vec3 o = rgb;
	if (band > 0.0) {
		vec2 g = vec2(inside_at(TEXTURE, UV + vec2(1.0, 0.0) / size) - inside_at(TEXTURE, UV - vec2(1.0, 0.0) / size), inside_at(TEXTURE, UV + vec2(0.0, 1.0) / size) - inside_at(TEXTURE, UV - vec2(0.0, 1.0) / size));
		if (length(g) > 0.0001 && pull > 0.0) {
			vec2 dir = normalize(g);
			vec4 deep = texture(effect_tex, clamp(UV + dir * (w_px - d_in + 1.5) / size, vec2(0.0), vec2(1.0)));
			if (deep.a > 0.5) {
				o = mix(o, straight(deep), pull * band);
			}
		}
		float l = dot(o, LUMA);
		o = mix(o, vec3(l), desaturate * band);
		o = o * (1.0 + brightness * band);
		float l2 = dot(o, LUMA);
		vec3 tinted = tint.rgb * (l2 / max(dot(tint.rgb, LUMA), 0.05));
		o = mix(o, tinted, tint_amount * band);
		o = clamp(o, 0.0, 1.0);
	}
	if (show_band) {
		COLOR = vec4(vec3(band), 1.0);
	} else {
		COLOR = vec4(o * a, a);
	}
}
