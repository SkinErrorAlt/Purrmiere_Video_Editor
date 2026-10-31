shader_type canvas_item;
render_mode blend_disabled;

uniform float level : hint_range(0.0, 1.0) = 0.6;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec4 colour : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform int rings : hint_range(1, 8) = 3;
uniform float speed : hint_range(0.0, 4.0) = 0.6;
uniform float width : hint_range(1.0, 60.0) = 6.0;
uniform float push : hint_range(0.0, 30.0) = 6.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }

void fragment() {
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float r = length(q);
	float maxr = length(vec2(asp, 1.0)) * 0.6;
	float px = px_scale / max(tex_size.y, 1.0);
	float L = 0.0;
	float disp = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= rings) {
			break;
		}
		float ph = fract(clip_time * speed * 0.5 + float(i) / float(rings));
		float rr = ph * maxr;
		float dd = (r - rr) / px;
		float fade = (1.0 - ph) * level;
		L += exp(-dd * dd / max(width * width, 0.01)) * fade;
		disp += exp(-dd * dd / max(width * width * 9.0, 0.01)) * fade * sign(dd);
	}
	vec2 dir = r > 0.00001 ? q / r : vec2(0.0);
	vec4 c = texture(TEXTURE, UV - dir / vec2(asp, 1.0) * disp * push * px);
	vec3 add = colour.rgb * L;
	float la = clamp(L, 0.0, 1.0);
	vec3 base = unp(c);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(a)), a);
}
