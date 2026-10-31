shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float width : hint_range(0.5, 8.0) = 2.0;
uniform float bright : hint_range(0.0, 1.0) = 1.0;
uniform float dark : hint_range(0.0, 1.0) = 0.7;
uniform float edge : hint_range(0.02, 0.8) = 0.12;
uniform float keep_detail : hint_range(0.0, 1.0) = 0.85;
uniform bool show = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float src_luma(vec2 uv) {
	return dot(straight(texture(effect_tex, clamp(uv, vec2(0.0), vec2(1.0)))), LUMA);
}

float soft_luma(sampler2D tex, vec2 uv) {
	return dot(straight(texture(tex, clamp(uv, vec2(0.0), vec2(1.0)))), LUMA);
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = straight(c);
	float y = dot(rgb, LUMA);
	float yb = soft_luma(TEXTURE, UV);
	float lo_b = yb;
	float hi_b = yb;
	float lo_s = y;
	float hi_s = y;
	float wr = max(width * ps * 2.0, 1.0);
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		vec2 dir = vec2(cos(ang), sin(ang)) * px;
		for (int j = 1; j <= 3; j++) {
			vec2 uv = UV + dir * wr * float(j) / 3.0;
			float b = soft_luma(TEXTURE, uv);
			float s = src_luma(uv);
			lo_b = min(lo_b, b);
			hi_b = max(hi_b, b);
			lo_s = min(lo_s, s);
			hi_s = max(hi_s, s);
		}
	}
	float range_s = hi_s - lo_s;
	float range_b = hi_b - lo_b;
	float edge_ok = smoothstep(edge * 0.6, edge, range_s);
	float struct_ok = smoothstep(0.4, 0.65, range_b / max(range_s, 0.0001));
	float w = edge_ok * mix(1.0, struct_ok, clamp(keep_detail, 0.0, 1.0));
	float target = y;
	if (y > hi_b) {
		target = mix(y, hi_b, clamp(bright, 0.0, 1.0) * w);
	} else if (y < lo_b) {
		target = mix(y, lo_b, clamp(dark, 0.0, 1.0) * w);
	}
	vec3 outc = clamp(rgb + vec3(target - y), 0.0, 1.0);
	if (show) {
		float moved = clamp(abs(target - y) * 8.0, 0.0, 1.0);
		outc = mix(vec3(y * 0.35), target < y ? vec3(1.0, 0.4, 0.2) : vec3(0.2, 0.6, 1.0), moved);
	}
	COLOR = vec4(outc * a, a);
}
