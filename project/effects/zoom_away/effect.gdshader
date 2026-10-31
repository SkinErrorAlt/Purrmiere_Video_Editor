shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int style : hint_range(0, 4) = 0;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.5;
uniform bool fade = true;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float feather : hint_range(0.0, 0.2) = 0.004;
uniform bool invert = false;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 moved_uv(vec2 uv, float p, vec2 asp, out float scale) {
	vec2 q = (uv - centre) * asp;
	scale = 1.0;
	if (style == 0 || style == 1) {
		bool grow = (style == 0) != invert;
		float e = p * p;
		scale = grow ? exp2(e * 4.0) : max(1.0 - e, 0.0001);
		q = q / scale;
	} else if (style == 2) {
		float e = p * p;
		scale = max(1.0 - e, 0.0001);
		float turn = e * 7.853982 * (invert ? -1.0 : 1.0);
		float cs = cos(turn);
		float sn = sin(turn);
		q = vec2(q.x * cs + q.y * sn, -q.x * sn + q.y * cs) / scale;
	} else {
		float e = p * p * (3.0 - 2.0 * p);
		bool left = (style == 3) != invert;
		float travel = e * (asp.x + 0.05) * (left ? -1.0 : 1.0);
		q = q - vec2(travel, 0.0);
	}
	return q / asp + centre;
}

float edge_keep(vec2 suv, float scale, float p) {
	if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
		return 0.0;
	}
	vec2 src_px = max(tex_size, vec2(1.0));
	float inside = min(min(suv.x, 1.0 - suv.x) * src_px.x, min(suv.y, 1.0 - suv.y) * src_px.y);
	float width = (feather * src_px.y + 1.0 / max(scale, 0.0001)) * clamp(p * 20.0, 0.0, 1.0);
	if (width < 0.0001) {
		return 1.0;
	}
	return smoothstep(0.0, 1.0, clamp(inside / width, 0.0, 1.0));
}

void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	vec2 asp = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	float shutter = clamp(blur_amount, 0.0, 1.0) * 0.4 * 4.0 * p * (1.0 - p);
	float p0 = clamp(p - shutter * 0.5, 0.0, 1.0);
	float p1 = clamp(p + shutter * 0.5, 0.0, 1.0);
	float s0;
	float s1;
	vec2 a0 = moved_uv(UV, p0, asp, s0);
	vec2 a1 = moved_uv(UV, p1, asp, s1);
	float travel_px = length((a1 - a0) * max(tex_size, vec2(1.0)));
	int n = int(clamp(ceil(travel_px / 2.0), 1.0, 24.0));
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec4 sum = vec4(0.0);
	for (int i = 0; i < 24; i++) {
		if (i >= n) {
			break;
		}
		float f = n > 1 ? (float(i) + jitter) / float(n) : 0.5;
		float pt = mix(p0, p1, f);
		float sc;
		vec2 suv = moved_uv(UV, pt, asp, sc);
		float keep = edge_keep(suv, sc, pt);
		if (keep > 0.0) {
			sum += texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0))) * keep;
		}
	}
	vec4 col = sum / float(n);
	float fade_mul = fade ? 1.0 - smoothstep(0.35, 1.0, p) : 1.0;
	bool zooming_in = (style == 0 && !invert) || (style == 1 && invert);
	if (zooming_in) {
		fade_mul = min(fade_mul, 1.0 - smoothstep(0.55, 1.0, p));
	}
	col *= clamp(fade_mul, 0.0, 1.0);
	COLOR = vec4(clamp(col.rgb, vec3(0.0), vec3(col.a)), clamp(col.a, 0.0, 1.0));
}
