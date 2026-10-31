shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform float left : hint_range(0.0, 1.0) = 0.8;
uniform float top : hint_range(0.0, 1.0) = 0.05;
uniform float right : hint_range(0.0, 1.0) = 0.04;
uniform float bottom : hint_range(0.0, 1.0) = 0.83;
uniform float band : hint_range(1.0, 12.0) = 3.0;
uniform float feather : hint_range(0.0, 30.0) = 3.0;
uniform float grain : hint_range(0.0, 0.1) = 0.01;
uniform bool show_box = false;

vec4 side_sample(sampler2D tex, vec2 uv, vec2 outward, vec2 along, vec2 px, float reach) {
	vec4 s = vec4(0.0);
	for (int k = 1; k <= 4; k++) {
		float d = reach * float(k) / 4.0;
		for (int j = -1; j <= 1; j++) {
			vec2 p = uv + outward * px * d + along * px * float(j);
			s += texture(tex, clamp(p, vec2(0.0), vec2(1.0)));
		}
	}
	return s / 12.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 px = 1.0 / size;
	float ps = max(px_scale, 0.0001);
	float x0 = clamp(left, 0.0, 1.0);
	float x1 = clamp(1.0 - right, 0.0, 1.0);
	float y0 = clamp(top, 0.0, 1.0);
	float y1 = clamp(1.0 - bottom, 0.0, 1.0);
	vec4 c = texture(TEXTURE, UV);
	vec4 outc = c;
	bool has_box = x1 - x0 > px.x && y1 - y0 > px.y;
	if (has_box && UV.x > x0 && UV.x < x1 && UV.y > y0 && UV.y < y1) {
		float reach = max(band * ps, 1.0);
		float gap = 0.5;
		vec2 edge_uv = px * (gap + reach);
		bool has_l = x0 - edge_uv.x >= 0.0;
		bool has_r = x1 + edge_uv.x <= 1.0;
		bool has_t = y0 - edge_uv.y >= 0.0;
		bool has_b = y1 + edge_uv.y <= 1.0;
		float dl = max((UV.x - x0) * size.x, 0.5);
		float dr = max((x1 - UV.x) * size.x, 0.5);
		float dt = max((UV.y - y0) * size.y, 0.5);
		float db = max((y1 - UV.y) * size.y, 0.5);
		vec4 sum = vec4(0.0);
		float wsum = 0.0;
		if (has_l) {
			float w = 1.0 / dl;
			sum += side_sample(TEXTURE, vec2(x0 - px.x * gap, UV.y), vec2(-1.0, 0.0), vec2(0.0, 1.0), px, reach) * w;
			wsum += w;
		}
		if (has_r) {
			float w = 1.0 / dr;
			sum += side_sample(TEXTURE, vec2(x1 + px.x * gap, UV.y), vec2(1.0, 0.0), vec2(0.0, 1.0), px, reach) * w;
			wsum += w;
		}
		if (has_t) {
			float w = 1.0 / dt;
			sum += side_sample(TEXTURE, vec2(UV.x, y0 - px.y * gap), vec2(0.0, -1.0), vec2(1.0, 0.0), px, reach) * w;
			wsum += w;
		}
		if (has_b) {
			float w = 1.0 / db;
			sum += side_sample(TEXTURE, vec2(UV.x, y1 + px.y * gap), vec2(0.0, 1.0), vec2(1.0, 0.0), px, reach) * w;
			wsum += w;
		}
		if (wsum > 0.0) {
			vec4 fill = sum / wsum;
			float n = (hash(floor(UV * size) + vec2(floor(time * 30.0) * 7.13, 0.0)) - 0.5) * 2.0 * grain;
			fill.rgb = clamp(fill.rgb + vec3(n) * fill.a, vec3(0.0), vec3(fill.a));
			float inside = min(min(dl, dr), min(dt, db));
			float fw = feather * ps;
			float k = fw > 0.0 ? smoothstep(0.0, fw, inside) : 1.0;
			outc = mix(c, fill, k);
		}
	}
	if (show_box && has_box) {
		vec2 p = UV * size;
		vec2 lo = vec2(x0, y0) * size;
		vec2 hi = vec2(x1, y1) * size;
		float dx = min(abs(p.x - lo.x), abs(p.x - hi.x));
		float dy = min(abs(p.y - lo.y), abs(p.y - hi.y));
		bool within_x = p.x > lo.x - 1.5 && p.x < hi.x + 1.5;
		bool within_y = p.y > lo.y - 1.5 && p.y < hi.y + 1.5;
		float line = 0.0;
		if ((dx < 1.5 && within_y) || (dy < 1.5 && within_x)) {
			line = 1.0;
		}
		outc = mix(outc, vec4(1.0, 0.85, 0.1, 1.0), line);
	}
	COLOR = outc;
}
