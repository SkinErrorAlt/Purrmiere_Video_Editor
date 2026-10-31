shader_type canvas_item;
render_mode blend_disabled;

uniform float tiles : hint_range(1.0, 32.0) = 3.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform bool mirror = true;
uniform bool keep_aspect = true;
uniform vec2 tex_size;
uniform float clip_time = 0.0;
uniform float scroll_angle : hint_range(-180.0, 180.0) = 90.0;
uniform float speed : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	vec2 n = vec2(max(tiles, 1.0));
	if (keep_aspect) {
		n.y = n.x * max(tex_size.y, 1.0) / max(tex_size.x, 1.0);
		n.y = max(n.y, 1.0);
	}
	vec2 off = offset;
	if (speed != 0.0) {
		float sa = radians(scroll_angle);
		off -= vec2(sin(sa), -cos(sa)) * speed * clip_time / n;
	}
	vec2 p = (UV + off) * n;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	if (mirror) {
		if (mod(cell.x, 2.0) >= 1.0) { f.x = 1.0 - f.x; }
		if (mod(cell.y, 2.0) >= 1.0) { f.y = 1.0 - f.y; }
	}
	COLOR = texture(TEXTURE, clamp(f, vec2(0.0), vec2(1.0)));
}
