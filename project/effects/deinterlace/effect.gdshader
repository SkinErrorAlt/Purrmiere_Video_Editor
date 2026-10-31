shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int method : hint_range(0, 2) = 0;
uniform int keep : hint_range(0, 1) = 0;
uniform float threshold : hint_range(0.01, 0.3) = 0.04;
uniform bool show = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 at(sampler2D tex, vec2 uv) {
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

float lum(vec4 c) {
	return c.a > 0.0001 ? dot(clamp(c.rgb / c.a, 0.0, 1.0), LUMA) : 0.0;
}

vec4 edge_directed(sampler2D tex, vec2 uv, vec2 sx, vec2 sy) {
	float best = 1e9;
	vec4 pick = 0.5 * (at(tex, uv - sy) + at(tex, uv + sy));
	for (int k = -2; k <= 2; k++) {
		float fk = float(k);
		float cost = 0.0;
		for (int j = -1; j <= 1; j++) {
			float fj = float(j);
			cost += abs(lum(at(tex, uv - sy + sx * (fk + fj))) - lum(at(tex, uv + sy + sx * (-fk + fj))));
		}
		cost += abs(fk) * 0.01;
		if (cost < best) {
			best = cost;
			pick = 0.5 * (at(tex, uv - sy + sx * fk) + at(tex, uv + sy - sx * fk));
		}
	}
	return pick;
}

float comb_at(sampler2D tex, vec2 uv, vec2 sy) {
	vec3 c = at(tex, uv).rgb;
	vec3 u = at(tex, uv - sy).rgb;
	vec3 d = at(tex, uv + sy).rgb;
	vec3 u2 = at(tex, uv - sy * 2.0).rgb;
	vec3 d2 = at(tex, uv + sy * 2.0).rgb;
	vec3 du = c - u;
	vec3 dd = c - d;
	float same_sign = step(0.0, dot(du, dd));
	float v = min(max(abs(du.r), max(abs(du.g), abs(du.b))), max(abs(dd.r), max(abs(dd.g), abs(dd.b)))) * same_sign;
	vec3 o1 = abs(c - u2);
	vec3 o2 = abs(c - d2);
	float own = min(max(o1.r, max(o1.g, o1.b)), max(o2.r, max(o2.g, o2.b)));
	return v * (1.0 - smoothstep(0.35, 0.7, own / max(v, 0.0001)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 sx = vec2(ps / size.x, 0.0);
	vec2 sy = vec2(0.0, ps / size.y);
	vec4 c = texture(TEXTURE, UV);
	float line = floor(UV.y * size.y / ps);
	bool rebuild = int(mod(line, 2.0)) != keep;
	vec4 outc = c;
	float combed = 0.0;
	if (method == 2) {
		outc = 0.5 * c + 0.25 * (at(TEXTURE, UV - sy) + at(TEXTURE, UV + sy));
		combed = 1.0;
	} else if (rebuild) {
		vec4 fill = edge_directed(TEXTURE, UV, sx, sy);
		if (method == 1) {
			outc = fill;
			combed = 1.0;
		} else {
			float v = (comb_at(TEXTURE, UV - sx, sy) + comb_at(TEXTURE, UV, sy) + comb_at(TEXTURE, UV + sx, sy)) / 3.0;
			combed = smoothstep(threshold * 0.5, threshold, v);
			outc = mix(c, fill, combed);
		}
	}
	if (show) {
		float y = lum(c);
		outc = vec4(mix(vec3(y * 0.35), vec3(1.0, 0.3, 0.6), combed), 1.0);
	}
	COLOR = outc;
}
