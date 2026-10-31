shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float angle : hint_range(-45.0, 45.0) = 0.0;
uniform int fill : hint_range(0, 2) = 0;
uniform bool guides = false;
uniform vec4 guide_colour : source_color = vec4(1.0, 0.85, 0.2, 0.8);

vec4 fetch(sampler2D tex, vec2 uv) {
	if (fill == 2) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
		return texture(tex, uv);
	}
	vec2 m = mod(uv, 2.0);
	return texture(tex, clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0)));
}

float line_cover(float d, float half_w) {
	return clamp(half_w - abs(d) + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float th = radians(clamp(angle, -45.0, 45.0));
	float ac = abs(cos(th));
	float as = abs(sin(th));
	float z = 1.0;
	if (fill == 0) {
		z = max((size.x * ac + size.y * as) / size.x, (size.x * as + size.y * ac) / size.y);
	}
	vec2 q = (UV - 0.5) * size / z;
	float cs = cos(th);
	float sn = sin(th);
	q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);
	vec4 c = fetch(TEXTURE, q / size + 0.5);
	if (guides) {
		vec2 p = UV * size;
		float w = max(0.75 * px_scale, 0.5);
		float g = 0.0;
		for (int i = 1; i < 6; i++) {
			float f = float(i) / 6.0;
			float strong = i == 3 ? 1.0 : 0.55;
			g = max(g, line_cover(p.y - f * size.y, w) * strong);
			g = max(g, line_cover(p.x - f * size.x, w) * strong * 0.8);
		}
		float k = g * guide_colour.a;
		float alpha = max(c.a, k);
		c = vec4(mix(c.rgb, guide_colour.rgb, k), alpha);
	}
	COLOR = c;
}
