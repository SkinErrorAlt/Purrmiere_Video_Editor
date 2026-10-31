shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float seq_fps = 30.0;
uniform float graininess : hint_range(0.0, 10.0) = 6.0;
uniform float glow_amount : hint_range(0.0, 20.0) = 10.0;
uniform float clear_amount : hint_range(0.0, 20.0) = 15.0;
uniform vec4 glow_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float grain_size : hint_range(1.0, 8.0) = 1.0;
uniform bool new_grain = false;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	if (a < 0.0001) {
		COLOR = c;
	} else {
		vec3 rgb = clamp(c.rgb / a, 0.0, 1.0);
		float l = dot(rgb, LUMA);
		vec4 bl = texture(TEXTURE, UV);
		float lb = bl.a > 0.0001 ? bl.r / bl.a : l;
		float drive = max(l, lb * 1.04);
		float clear = clamp(clear_amount / 20.0, 0.0, 1.0);
		float glow = clamp(glow_amount / 20.0, 0.0, 1.0);
		float start = clamp(0.8 * clear - 0.32 * glow, 0.0, 0.95);
		float m = smoothstep(start, 1.0, drive);
		m = pow(m, mix(1.3, 0.75, glow));
		float strength = m * min(glow * 1.75, 1.0);
		vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
		float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
		vec2 cell = floor(UV * full / max(grain_size * ps, 1.0));
		float frame = new_grain ? floor(clip_time * max(seq_fps, 1.0) + 0.5) : 0.0;
		float n = hash12(cell + vec2(frame * 37.0, frame * 113.0));
		float n2 = hash12(cell * 1.37 + vec2(19.7 + frame * 7.0, 3.1));
		float speck = (n - 0.5) * 2.0;
		speck = sign(speck) * pow(abs(speck), 0.7);
		float gr = clamp(graininess / 10.0, 0.0, 1.0);
		float w = strength + speck * gr * 0.9 * m * (1.0 - 0.5 * strength) + (n2 > 1.0 - 0.06 * gr ? 0.6 * m : 0.0);
		w = clamp(w, 0.0, 1.0);
		vec3 outc = mix(rgb, glow_colour.rgb, w * glow_colour.a);
		COLOR = vec4(outc * a, a);
	}
}
