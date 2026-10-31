shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(8.0, 400.0) = 60.0;
uniform int facet : hint_range(0, 1) = 0;
uniform float magnify : hint_range(0.2, 4.0) = 1.5;
uniform float rim : hint_range(0.0, 0.5) = 0.12;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float s = max(cell * max(px_scale, 0.0001), 1.0);
	vec2 p = UV * sz / s;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 hh = r * 0.5;
	vec2 a = mod(p, r) - hh;
	vec2 b = mod(p - hh, r) - hh;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = p - gv;
	vec2 uv;
	if (facet == 0) {
		uv = 0.5 + gv * vec2(1.0, sz.x / sz.y) / magnify * 1.15;
	} else {
		uv = (id + gv / max(magnify, 0.01)) * s / sz;
	}
	vec2 ag = abs(gv);
	float hd = max(dot(ag, vec2(0.5, 0.8660254)), ag.x);
	float edge = smoothstep(0.5, 0.5 - max(rim, 0.001), hd);
	bool outside = uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0;
	vec4 t = outside ? vec4(0.0) : texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec4 base = texture(TEXTURE, UV);
	COLOR = vec4(t.rgb * edge, t.a) * step(0.0001, base.a);
}
