shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.35;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float static_amount : hint_range(0.0, 1.0) = 1.0;
uniform float roll : hint_range(0.0, 1.0) = 0.6;
uniform float tear : hint_range(0.0, 1.0) = 0.5;
uniform float colour_noise : hint_range(0.0, 1.0) = 0.25;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float fr = floor(clip_time * 30.0);
		float e = g;
		float roll_off = clamp(roll, 0.0, 1.0) * e * e * 1.7 * (is_in ? -1.0 : 1.0);
		vec2 uv = UV;
		uv.y = fract(uv.y + roll_off);
		float row = floor(UV.y * sz.y / (2.0 * ps));
		float tr = clamp(tear, 0.0, 1.0) * e;
		float wave = sin(uv.y * 38.0 + clip_time * 55.0) * 0.012 + sin(uv.y * 7.0 - clip_time * 23.0) * 0.02;
		float jag = (hash12(vec2(row * 0.37, fr)) - 0.5) * 0.08 * step(hash12(vec2(floor(row / 6.0), fr + 3.0)), 0.3);
		uv.x += tr * (wave + jag) + tr * tr * 0.06 * sin(uv.y * 3.1 + fr);
		vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
		vec4 pic = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * inside.x * inside.y;
		float a = pic.a;
		vec3 rgb = a > 0.0001 ? pic.rgb / a : vec3(0.0);
		float l = dot(rgb, LUMA);
		rgb = mix(rgb, vec3(l), clamp(e * 0.9, 0.0, 1.0));
		rgb *= 1.0 + 0.4 * e * sin(fr * 2.7);
		float gap = fract(UV.y + roll_off);
		float bar = min(1.0, abs(roll_off) * 25.0) * (1.0 - smoothstep(0.0, 0.035, gap) * smoothstep(0.0, 0.035, 1.0 - gap));
		rgb *= 1.0 - 0.85 * bar;
		vec2 cell = floor(UV * sz / (1.6 * ps));
		float n = hash12(cell + fr * vec2(13.1, 7.7));
		float rown = hash12(vec2(row, fr * 1.3));
		vec3 cn = hash32(cell + fr * vec2(5.3, 11.9));
		vec3 stat = mix(vec3(n), cn, clamp(colour_noise, 0.0, 1.0)) * (0.7 + 0.5 * rown);
		float sa = clamp(static_amount, 0.0, 1.0);
		float sw = sa * smoothstep(0.2, 0.9, e);
		float lines = step(0.985 - 0.25 * e, rown) * e * sa * 0.85;
		float k = clamp(max(sw, lines), 0.0, 1.0);
		vec3 o = mix(rgb, stat, k);
		float oa = mix(a, 1.0, k);
		COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
	}
}
