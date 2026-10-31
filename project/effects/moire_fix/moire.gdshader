shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 0.9;
uniform float radius : hint_range(1.0, 16.0) = 6.0;
uniform float fine : hint_range(0.01, 0.3) = 0.05;
uniform float grey_only : hint_range(0.0, 1.0) = 0.6;
uniform bool show = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float src_luma(vec2 uv) {
	return dot(straight(texture(effect_tex, clamp(uv, vec2(0.0), vec2(1.0)))), LUMA);
}

vec2 chroma_of(vec3 c) {
	float y = dot(c, LUMA);
	return vec2((c.b - y) / 1.8556, (c.r - y) / 1.5748);
}

float detail_at(vec2 uv, vec2 px) {
	float c = src_luma(uv);
	float s = src_luma(uv + vec2(px.x, 0.0)) + src_luma(uv - vec2(px.x, 0.0)) + src_luma(uv + vec2(0.0, px.y)) + src_luma(uv - vec2(0.0, px.y));
	return abs(c - s * 0.25);
}

void fragment() {
	vec2 px = max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = straight(c);
	float y = dot(rgb, LUMA);
	vec2 own = chroma_of(rgb);
	vec2 soft = chroma_of(straight(texture(TEXTURE, UV)));
	float hits = step(fine, detail_at(UV, px) * 2.0);
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		vec2 o = vec2(cos(ang), sin(ang)) * 2.5 * px;
		hits += step(fine, detail_at(UV + o, px) * 2.0);
	}
	float busy = smoothstep(0.45, 0.75, hits / 13.0);
	float grey = 1.0 - smoothstep(0.04, 0.12, length(soft));
	float w = clamp(strength, 0.0, 1.0) * busy * mix(1.0, grey, clamp(grey_only, 0.0, 1.0));
	vec2 chroma = mix(own, soft, w);
	float r = y + 1.5748 * chroma.y;
	float b = y + 1.8556 * chroma.x;
	float g = (y - 0.2126 * r - 0.0722 * b) / 0.7152;
	vec3 outc = clamp(vec3(r, g, b), 0.0, 1.0);
	if (show) {
		outc = mix(vec3(y * 0.35), vec3(1.0, 0.8, 0.2), w);
	}
	COLOR = vec4(outc * a, a);
}
