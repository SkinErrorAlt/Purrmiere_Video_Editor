shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 light = vec2(0.3, 0.2);
uniform float depth : hint_range(0.0, 2.0) = 0.25;
uniform float softness : hint_range(0.0, 60.0) = 6.0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.6;
uniform bool shadow_only = false;
uniform vec2 tex_size;
uniform float px_scale;

float sa(sampler2D tx, vec2 p) {
	if (p.x < 0.0 || p.y < 0.0 || p.x > 1.0 || p.y > 1.0) { return 0.0; }
	return texture(tx, p).a;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 q = light + (UV - light) / (1.0 + depth);
	vec2 r = vec2(softness * max(px_scale, 0.0001)) / max(tex_size, vec2(1.0));
	float a = sa(TEXTURE, q) * 2.0;
	for (int i = 0; i < 8; i++) {
		float t = float(i) * 0.785398;
		vec2 d = vec2(cos(t), sin(t));
		a += sa(TEXTURE, q + d * r) * 0.75 + sa(TEXTURE, q + d * r * 0.45) * 0.25;
	}
	a /= 10.0;
	vec4 sh = vec4(colour.rgb, 1.0) * a * opacity * colour.a;
	COLOR = shadow_only ? sh : c + sh * (1.0 - c.a);
}
