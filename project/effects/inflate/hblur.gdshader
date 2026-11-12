shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 dir = vec2(1.0, 0.0);
uniform bool clip_to_raw = false;
uniform sampler2D raw_tex : filter_linear, repeat_disable;
uniform float roundness : hint_range(0.0, 40.0) = 8.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float unpack(vec4 c) {
	return c.r + c.g / 255.0;
}

void fragment() {
	float sigma = max(roundness * max(px_scale, 0.0001), 0.35);
	float reach = sigma * 2.5;
	int n = int(clamp(ceil(reach), 1.0, 24.0));
	float stp = max(reach / float(n), 1.0);
	vec2 px = dir / max(tex_size, vec2(1.0));
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = -n; i <= n; i++) {
		float o = float(i) * stp;
		float w = exp(-0.5 * o * o / (sigma * sigma));
		sum += unpack(texture(TEXTURE, UV + px * o)) * w;
		wsum += w;
	}
	float v = clamp(sum / max(wsum, 0.0001), 0.0, 1.0);
	if (clip_to_raw) {
		v = min(v, unpack(texture(raw_tex, UV)) * 1.35);
	}
	float hi = floor(v * 255.0) / 255.0;
	float cr = clip_to_raw ? texture(raw_tex, UV).b : texture(TEXTURE, UV).b;
	COLOR = vec4(hi, fract(v * 255.0), cr, 1.0);
}
