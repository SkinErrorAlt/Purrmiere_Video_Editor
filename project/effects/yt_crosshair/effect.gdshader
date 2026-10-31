shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 position = vec2(0.5, 0.5);
uniform int style : hint_range(0, 4) = 0;
uniform float size : hint_range(0.005, 0.4) = 0.03;
uniform float thickness : hint_range(0.5, 20.0) = 2.5;
uniform float spread : hint_range(0.0, 1.0) = 0.25;
uniform vec4 colour : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.6;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h);
}

float shape(vec2 p, float g) {
	float d = 1e5;
	float lo = g;
	float hi = g + 1.0;
	if (style == 0) {
		d = min(d, seg(p, vec2(lo, 0.0), vec2(hi, 0.0)));
		d = min(d, seg(p, vec2(-lo, 0.0), vec2(-hi, 0.0)));
		d = min(d, seg(p, vec2(0.0, lo), vec2(0.0, hi)));
		d = min(d, seg(p, vec2(0.0, -lo), vec2(0.0, -hi)));
	} else if (style == 1) {
		d = max(length(p) - 0.12, 0.0);
	} else if (style == 2) {
		d = min(abs(length(p) - (0.8 + g)), max(length(p) - 0.1, 0.0));
	} else if (style == 3) {
		d = min(seg(p, vec2(-0.7, 0.45 + g), vec2(0.0, g)), seg(p, vec2(0.7, 0.45 + g), vec2(0.0, g)));
	} else {
		d = min(d, seg(p, vec2(lo, 0.0), vec2(hi, 0.0)));
		d = min(d, seg(p, vec2(-lo, 0.0), vec2(-hi, 0.0)));
		d = min(d, seg(p, vec2(0.0, lo), vec2(0.0, hi)));
		d = min(d, max(length(p) - 0.08, 0.0));
	}
	return d;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float unit = max(size, 0.0001);
	vec2 p = (UV - position) * vec2(sz.x / sz.y, 1.0) / unit;
	float d = shape(p, 0.2 + spread * 1.2);
	float th = thickness * px_scale * 0.5 / (sz.y * unit);
	float aa = 1.0 / (sz.y * unit);
	float core = 1.0 - smoothstep(th - aa, th + aa, d);
	float edge = (1.0 - smoothstep(th + 2.0 * aa * px_scale - aa, th + 2.0 * aa * px_scale + aa, d)) * outline;
	vec3 rgb = c.rgb * (1.0 - edge);
	float al = c.a + edge * (1.0 - c.a);
	float ac = core * colour.a;
	rgb = rgb * (1.0 - ac) + colour.rgb * ac;
	al = al + ac * (1.0 - al);
	COLOR = vec4(rgb, al);
}
