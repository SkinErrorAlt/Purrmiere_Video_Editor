shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float scale : hint_range(1.0, 4.0) = 1.5;
uniform float sharpness : hint_range(0.0, 1.0) = 0.6;
uniform float noise : hint_range(0.0, 0.1) = 0.02;
uniform bool brightness_only = true;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec2 px = max(scale, 1.0) * max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	vec4 src = texture(TEXTURE, UV);
	float alpha = src.a;
	vec3 e = alpha > 0.0001 ? clamp(src.rgb / alpha, 0.0, 1.0) : vec3(0.0);
	vec3 a = at(TEXTURE, UV + px * vec2(-1.0, -1.0));
	vec3 b = at(TEXTURE, UV + px * vec2(0.0, -1.0));
	vec3 c = at(TEXTURE, UV + px * vec2(1.0, -1.0));
	vec3 d = at(TEXTURE, UV + px * vec2(-1.0, 0.0));
	vec3 f = at(TEXTURE, UV + px * vec2(1.0, 0.0));
	vec3 g = at(TEXTURE, UV + px * vec2(-1.0, 1.0));
	vec3 h = at(TEXTURE, UV + px * vec2(0.0, 1.0));
	vec3 i = at(TEXTURE, UV + px * vec2(1.0, 1.0));
	vec3 mn = min(min(min(d, e), min(f, b)), h);
	vec3 mn2 = min(mn, min(min(a, c), min(g, i)));
	vec3 lo9 = mn2;
	mn += mn2;
	vec3 mx = max(max(max(d, e), max(f, b)), h);
	vec3 mx2 = max(mx, max(max(a, c), max(g, i)));
	vec3 hi9 = mx2;
	mx += mx2;
	vec3 amp = clamp(min(mn, vec3(2.0) - mx) / max(mx, vec3(0.0001)), 0.0, 1.0);
	amp = sqrt(amp);
	float peak = -1.0 / mix(8.0, 5.0, clamp(sharpness, 0.0, 1.0));
	vec3 spread = hi9 - lo9;
	float range = max(spread.r, max(spread.g, spread.b));
	float gate = noise > 0.0 ? smoothstep(noise * 0.5, noise * 1.5, range) : 1.0;
	vec3 w = amp * peak * gate;
	vec3 sharp = ((b + d + f + h) * w + e) / (vec3(1.0) + 4.0 * w);
	sharp = clamp(sharp, lo9 - vec3(0.03), hi9 + vec3(0.03));
	sharp = clamp(sharp, 0.0, 1.0);
	vec3 outc = sharp;
	if (brightness_only) {
		outc = clamp(e + vec3(dot(sharp - e, LUMA)), 0.0, 1.0);
	}
	if (sharpness <= 0.0) {
		outc = e;
	}
	COLOR = vec4(outc * alpha, alpha);
}
