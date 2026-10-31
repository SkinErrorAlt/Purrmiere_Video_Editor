shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.85;
uniform float saturation : hint_range(0.0, 5.0) = 2.4;
uniform float contrast : hint_range(0.0, 3.0) = 1.8;
uniform float sharpen : hint_range(0.0, 8.0) = 3.0;
uniform float crush : hint_range(0.0, 1.0) = 0.55;
uniform float noise : hint_range(0.0, 1.0) = 0.4;
uniform float heat : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 straight(sampler2D tex, vec2 pix, vec2 sz) {
	vec4 c = texture(tex, clamp(pix / sz, vec2(0.0), vec2(1.0)));
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 orig = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float r = 3.0 * ps;
	vec3 avg = (straight(TEXTURE, pix + vec2(r, 0.0), sz) + straight(TEXTURE, pix - vec2(r, 0.0), sz) + straight(TEXTURE, pix + vec2(0.0, r), sz) + straight(TEXTURE, pix - vec2(0.0, r), sz)) * 0.25;
	vec3 rgb = orig + max(sharpen, 0.0) * (orig - avg);
	float cr = clamp(crush, 0.0, 1.0);
	if (cr > 0.0) {
		float bs = max(8.0 * ps * (1.0 + 1.5 * cr), 2.0);
		vec2 origin = floor(pix / bs) * bs;
		float q = bs * 0.25;
		vec3 blk = (straight(TEXTURE, origin + vec2(q, q), sz) + straight(TEXTURE, origin + vec2(3.0 * q, q), sz) + straight(TEXTURE, origin + vec2(q, 3.0 * q), sz) + straight(TEXTURE, origin + vec2(3.0 * q, 3.0 * q), sz)) * 0.25;
		float flat_area = 1.0 - smoothstep(0.04, 0.3, length(orig - blk));
		rgb = mix(rgb, blk + (rgb - avg) * 0.5, cr * flat_area * 0.85);
		float l = dot(rgb, LUMA);
		rgb = mix(rgb, vec3(l) + (blk - vec3(dot(blk, LUMA))), cr * 0.6);
	}
	float grey = dot(rgb, LUMA);
	rgb = mix(vec3(grey), rgb, max(saturation, 0.0));
	rgb = (rgb - 0.5) * max(contrast, 0.0) + 0.5;
	float h = clamp(heat, 0.0, 1.0);
	rgb = rgb * vec3(1.0 + 0.6 * h, 1.0 + 0.1 * h, 1.0 - 0.65 * h) + vec3(0.08, 0.01, -0.05) * h;
	float grain = hash12(floor(pix / max(2.0 * ps, 1.0)) + vec2(mod(float(seed), 997.0) * 3.1, mod(floor(clip_time * 24.0), 512.0) * 1.7)) - 0.5;
	rgb += grain * clamp(noise, 0.0, 1.0) * 0.5;
	float levels = mix(48.0, 6.0, cr);
	rgb = floor(clamp(rgb, 0.0, 1.0) * levels + 0.5) / levels;
	rgb = mix(orig, rgb, clamp(amount, 0.0, 1.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
