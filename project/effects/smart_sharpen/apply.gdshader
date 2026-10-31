shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float amount : hint_range(0.0, 5.0) = 1.2;
uniform float radius : hint_range(0.3, 10.0) = 1.0;
uniform float halos : hint_range(0.0, 1.0) = 0.1;
uniform float noise : hint_range(0.0, 0.2) = 0.01;
uniform float shadow_fade : hint_range(0.0, 1.0) = 0.3;
uniform float highlight_fade : hint_range(0.0, 1.0) = 0.2;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const vec2 RING[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071), vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

float luma_at(vec2 uv) {
	vec4 s = texture(effect_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return s.a > 0.0001 ? dot(clamp(s.rgb / s.a, 0.0, 1.0), LUMA) : 0.0;
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 b = texture(TEXTURE, UV);
	vec3 blurred = b.a > 0.0001 ? clamp(b.rgb / b.a, 0.0, 1.0) : rgb;
	float y = dot(rgb, LUMA);
	float d = y - dot(blurred, LUMA);
	float gate = noise > 0.0 ? smoothstep(noise * 0.5, noise * 1.5, abs(d)) : 1.0;
	float tone = clamp(1.0 - shadow_fade * (1.0 - smoothstep(0.0, 0.35, y)) - highlight_fade * smoothstep(0.65, 1.0, y), 0.0, 1.0);
	float sharp = y + amount * d * gate * tone;
	float lo = y;
	float hi = y;
	vec2 px = 1.0 / tex_size;
	float reach = max(radius * px_scale * 1.5, 1.0);
	for (int i = 0; i < 8; i++) {
		float n1 = luma_at(UV + RING[i] * px);
		float n2 = luma_at(UV + RING[i] * px * reach);
		lo = min(lo, min(n1, n2));
		hi = max(hi, max(n1, n2));
	}
	float spread = hi - lo;
	float room = halos * halos * 4.0 * spread + halos * 0.02;
	sharp = clamp(sharp, lo - room, hi + room);
	vec3 outc = clamp(rgb + vec3(sharp - y), 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
