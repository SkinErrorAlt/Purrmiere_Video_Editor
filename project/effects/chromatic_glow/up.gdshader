shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform sampler2D level_tex : filter_linear, repeat_disable;
uniform float radius : hint_range(0.0, 1.0) = 0.7;
uniform float dispersion : hint_range(-1.0, 1.0) = 0.6;
uniform float falloff : hint_range(0.0, 1.0) = 0.7;
uniform bool tail = false;
uniform float level = 1.0;

const float HEAD = 16.0;

vec4 dec(sampler2D tex, vec2 uv) {
	vec4 e = texture(tex, uv);
	return e * e * HEAD;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 sum = dec(TEXTURE, UV) * 4.0;
	sum += dec(TEXTURE, UV + px * vec2(-1.0, 0.0)) * 2.0;
	sum += dec(TEXTURE, UV + px * vec2(1.0, 0.0)) * 2.0;
	sum += dec(TEXTURE, UV + px * vec2(0.0, -1.0)) * 2.0;
	sum += dec(TEXTURE, UV + px * vec2(0.0, 1.0)) * 2.0;
	sum += dec(TEXTURE, UV + px * vec2(-1.0, -1.0));
	sum += dec(TEXTURE, UV + px * vec2(1.0, -1.0));
	sum += dec(TEXTURE, UV + px * vec2(-1.0, 1.0));
	sum += dec(TEXTURE, UV + px * vec2(1.0, 1.0));
	vec4 up = sum / 16.0;
	float k = mix(0.6, 1.4, clamp(radius, 0.0, 1.0));
	float d = clamp(dispersion, -1.0, 1.0);
	vec3 reach = vec3(7.0) - vec3(max(-d, 0.0) * 5.0, abs(d) * 2.5, max(d, 0.0) * 5.0);
	vec3 keep = mix(vec3(0.3), vec3(1.0), smoothstep(reach + 1.0, reach - 1.0, vec3(level)));
	vec4 kc = vec4(k * keep, k);
	if (tail) {
		kc *= clamp(falloff, 0.0, 1.0) * 1.6;
	}
	vec4 lv = texture(level_tex, UV);
	vec4 v = up * kc + lv * lv * HEAD;
	vec4 enc = sqrt(clamp(v / HEAD, 0.0, 1.0));
	COLOR = clamp(enc + (hash12(FRAGCOORD.xy) - 0.5) / 255.0, 0.0, 1.0);
}
