shader_type canvas_item;
render_mode blend_disabled;

uniform float line_spacing : hint_range(2.0, 40.0) = 6.0;
uniform float angle : hint_range(-90.0, 90.0) = 30.0;
uniform vec4 ink : source_color = vec4(0.08, 0.1, 0.18, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.93, 0.86, 1.0);
uniform float wave : hint_range(0.0, 1.0) = 0.4;
uniform float contrast : hint_range(0.0, 3.0) = 1.2;
uniform bool cross_hatch = true;
uniform float cross_angle : hint_range(-90.0, 90.0) = -45.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float luma_of(vec4 s) {
	vec3 c = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float line_cover(vec2 pp, float deg, float gap, float shift, float thick) {
	float ra = radians(deg);
	vec2 n = vec2(-sin(ra), cos(ra));
	float v = dot(pp, n) / gap + shift;
	float f = abs(fract(v) - 0.5) * 2.0;
	float aa = max(fwidth(v) * 2.0, 0.001);
	float cover = smoothstep(1.0 - thick - aa, 1.0 - thick + aa, f);
	return cover * smoothstep(0.0, 0.06, thick);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float gap = max(line_spacing * px_scale, 1.5);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	float lsum = luma_of(c) * 2.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		vec2 off = vec2(cos(ang), sin(ang)) * gap * 0.6 / dims;
		lsum += luma_of(texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0))));
	}
	float lb = lsum / 10.0;
	float l = clamp((lb - 0.5) * contrast + 0.5, 0.0, 1.0);
	float d = 1.0 - l;
	vec2 pp = UV * dims;
	float shift = (lb - 0.5) * wave * 2.0;
	float cover = line_cover(pp, angle, gap, shift, d * 0.95);
	if (cross_hatch) {
		float t2 = clamp((d - 0.45) / 0.55, 0.0, 1.0) * 0.8;
		cover = max(cover, line_cover(pp, cross_angle, gap, shift, t2));
	}
	vec3 rgb = mix(paper.rgb, ink.rgb, cover * ink.a);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
