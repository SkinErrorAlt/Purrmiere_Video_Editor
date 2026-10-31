shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mean_tex : filter_nearest, repeat_disable;
uniform sampler2D min_tex : filter_nearest, repeat_disable;
uniform sampler2D max_tex : filter_nearest, repeat_disable;
uniform int stage = 2;
uniform bool per_channel = true;
uniform bool snap_midtones = true;
uniform float clip_black : hint_range(0.0, 10.0) = 0.5;
uniform float clip_white : hint_range(0.0, 10.0) = 0.5;

const float GRID_X = 8.0;
const float GRID_Y = 4.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 grid_sum(sampler2D tex) {
	vec4 total = vec4(0.0);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			total += texture(tex, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y));
		}
	}
	return total;
}

vec3 neutral_gamma(vec3 m) {
	vec3 mm = clamp(m, vec3(0.02), vec3(0.98));
	float target = clamp(dot(mm, LUMA), 0.02, 0.98);
	return clamp(log(vec3(target)) / log(mm), vec3(0.2), vec3(5.0));
}

void measured(out vec3 lo, out vec3 span, out vec3 g) {
	lo = vec3(1.0);
	vec3 hi = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 8; i++) {
			vec2 uv = (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y);
			lo = min(lo, texture(min_tex, uv).rgb);
			hi = max(hi, texture(max_tex, uv).rgb);
		}
	}
	vec4 total = grid_sum(mean_tex);
	vec3 mean = total.a > 0.0001 ? clamp(total.rgb / total.a, 0.0, 1.0) : vec3(0.5);
	if (!per_channel) {
		lo = vec3(min(lo.r, min(lo.g, lo.b)));
		hi = vec3(max(hi.r, max(hi.g, hi.b)));
	}
	vec3 found = step(lo, hi);
	span = max(hi - lo, vec3(0.0));
	lo = lo + span * clamp(clip_black, 0.0, 10.0) * 0.01;
	hi = hi - span * clamp(clip_white, 0.0, 10.0) * 0.01;
	span = max(hi - lo, vec3(0.05));
	lo = mix(vec3(0.0), lo, found);
	span = mix(vec3(1.0), span, found);
	g = snap_midtones ? neutral_gamma((mean - lo) / span) : vec3(1.0);
}

vec3 encode_hi(vec3 v) {
	return floor(clamp(v, 0.0, 0.99999) * 255.0) / 255.0;
}

vec3 encode_lo(vec3 v) {
	return fract(clamp(v, 0.0, 0.99999) * 255.0);
}

vec3 decode(vec3 hi, vec3 lo) {
	return (hi * 255.0 + lo) / 255.0;
}

void fragment() {
	if (stage == 0) {
		vec3 lo;
		vec3 span;
		vec3 g;
		measured(lo, span, g);
		vec2 src = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
		vec2 foot = max(src * SCREEN_PIXEL_SIZE, vec2(1.0));
		int nx = int(clamp(ceil(foot.x), 1.0, 16.0));
		int ny = int(clamp(ceil(foot.y), 1.0, 16.0));
		vec2 stride = foot / vec2(float(nx), float(ny));
		vec2 origin = UV * src - foot * 0.5;
		vec4 acc = vec4(0.0);
		for (int j = 0; j < 16; j++) {
			if (j >= ny) {
				break;
			}
			for (int i = 0; i < 16; i++) {
				if (i >= nx) {
					break;
				}
				vec2 p = origin + (vec2(float(i), float(j)) + 0.5) * stride;
				vec4 s = texture(effect_tex, clamp(p / src, vec2(0.0), vec2(1.0)));
				vec3 v = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : vec3(0.0);
				acc += vec4(pow(clamp((v - lo) / span, 0.0, 1.0), g) * s.a, s.a);
			}
		}
		COLOR = acc / float(nx * ny);
	} else if (stage == 1) {
		vec3 lo;
		vec3 span;
		vec3 g;
		measured(lo, span, g);
		if (snap_midtones) {
			vec4 fixed = vec4(0.0);
			for (int j = 0; j < 4; j++) {
				for (int i = 0; i < 8; i++) {
					fixed += texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / vec2(GRID_X, GRID_Y));
				}
			}
			if (fixed.a > 0.0001) {
				g *= neutral_gamma(fixed.rgb / fixed.a);
			}
		}
		vec3 gcode = (log2(clamp(g, vec3(0.04), vec3(25.0))) + 5.0) / 10.0;
		int region = int(clamp(floor(UV.x * 4.0), 0.0, 3.0));
		vec3 outc = lo;
		if (region == 1) {
			outc = clamp(span, 0.0, 1.0);
		} else if (region == 2) {
			outc = encode_hi(gcode);
		} else if (region == 3) {
			outc = encode_lo(gcode);
		}
		COLOR = vec4(outc, 1.0);
	} else {
		vec3 lo = texture(TEXTURE, vec2(0.125, 0.5)).rgb;
		vec3 span = max(texture(TEXTURE, vec2(0.375, 0.5)).rgb, vec3(0.01));
		vec3 gcode = decode(texture(TEXTURE, vec2(0.625, 0.5)).rgb, texture(TEXTURE, vec2(0.875, 0.5)).rgb);
		vec3 g = exp2(gcode * 10.0 - 5.0);
		vec4 c = texture(effect_tex, UV);
		float a = c.a;
		vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
		vec3 outc = pow(clamp((rgb - lo) / span, 0.0, 1.0), g);
		COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
	}
}
