shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/sound.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.7;
uniform float size : hint_range(0.5, 6.0) = 1.8;
uniform float colour_noise : hint_range(0.0, 1.0) = 0.35;
uniform float crush : hint_range(0.0, 1.0) = 0.4;
uniform float calm : hint_range(0.0, 1.0) = 0.0;
uniform float jolt : hint_range(0.0, 10.0) = 2.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float gnoise(vec2 p) {
	return snd_vnoise(p) + snd_vnoise(p * 2.13 + 3.1) * 0.5 + snd_vnoise(p * 4.37 + 7.7) * 0.25 - 0.875;
}

void fragment() {
	float harsh = smoothstep(0.05, 0.7, snd_noise);
	float k = clamp(calm + (1.0 - calm) * harsh, 0.0, 1.0);
	float frame = floor(time * 24.0);
	vec2 fj = (snd_hash2(vec2(frame, 3.7)) - 0.5) * jolt * harsh * px_scale / max(tex_size, vec2(1.0));
	vec4 src = texture(TEXTURE, clamp(UV + fj, vec2(0.0), vec2(1.0)));
	float a = src.a;
	vec3 rgb = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec2 pix = UV * tex_size / max(px_scale, 0.0001);
	float gs = max(size * mix(1.0, 1.7, harsh), 0.3);
	vec2 off = snd_hash2(vec2(frame * 1.31, frame * 0.77)) * 512.0;
	float g = gnoise(pix / gs + off);
	vec3 cg = vec3(gnoise(pix / (gs * 7.0) + off + 11.0), gnoise(pix / (gs * 7.0) + off + 23.0), gnoise(pix / (gs * 7.0) + off + 37.0));
	float y = dot(rgb, LUMA);
	float mids = 0.35 + 2.4 * y * (1.0 - y);
	rgb += vec3(g) * 0.3 * grain * k * mids;
	rgb += (cg - vec3(dot(cg, vec3(0.333)))) * 0.3 * colour_noise * k * mids;
	float cr = crush * harsh;
	rgb = (rgb - 0.06 * cr) / (1.0 - 0.1 * cr);
	vec3 yv = vec3(dot(rgb, LUMA));
	rgb = mix(yv, rgb, 1.0 + 0.25 * cr);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
