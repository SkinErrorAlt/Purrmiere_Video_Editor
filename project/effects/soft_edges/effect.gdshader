shader_type canvas_item;
render_mode blend_disabled;

uniform int shape : hint_range(0, 2) = 0;
uniform float size : hint_range(0.0, 0.5) = 0.12;
uniform float corner : hint_range(0.0, 0.5) = 0.12;
uniform float curve : hint_range(0.2, 4.0) = 1.0;
uniform float inset : hint_range(0.0, 0.4) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		float ar = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
		vec2 p = (UV - 0.5) * vec2(ar, 1.0) * 2.0;
		vec2 half_box = vec2(ar, 1.0) * (1.0 - inset * 2.0);
		float d;
		if (shape == 2) {
			vec2 q = p / max(half_box, vec2(0.0001));
			d = (1.0 - length(q)) * min(half_box.x, half_box.y);
		} else if (shape == 1) {
			float r = corner * min(half_box.x, half_box.y);
			vec2 q = abs(p) - (half_box - vec2(r));
			float outside_d = length(max(q, vec2(0.0))) - r;
			d = -outside_d;
		} else {
			vec2 q = half_box - abs(p);
			d = min(q.x, q.y);
		}
		float f = max(size, 0.0) * min(half_box.x, half_box.y) * 2.0;
		float a = f <= 0.0 ? step(0.0, d) : clamp(d / f, 0.0, 1.0);
		a = pow(a, max(curve, 0.2));
		vec4 soft = base;
		soft.a = base.a * a;
		soft.rgb = base.rgb * a;
		COLOR = mix(base, soft, strength);
	}
}
