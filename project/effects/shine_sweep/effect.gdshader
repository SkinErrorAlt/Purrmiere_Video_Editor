shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float starts_at : hint_range(0.0, 600.0) = 0.2;
uniform float sweep_time : hint_range(0.05, 5.0) = 0.7;
uniform float repeat_every : hint_range(0.0, 30.0) = 2.5;
uniform float angle : hint_range(-180.0, 180.0) = 105.0;
uniform float width : hint_range(4.0, 800.0) = 90.0;
uniform float softness : hint_range(0.0, 1.0) = 0.6;
uniform float brightness : hint_range(0.0, 2.0) = 0.8;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool second_line = true;

float band(float d, float hw, float soft) {
	float inner = hw * (1.0 - clamp(soft, 0.0, 1.0));
	return 1.0 - smoothstep(inner, max(hw, inner + 0.5), abs(d));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = clip_time - starts_at;
	if (repeat_every > 0.001 && t >= 0.0) {
		t = mod(t, repeat_every);
	}
	float q = t / max(sweep_time, 0.01);
	if (q < 0.0 || q > 1.0) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float rad = radians(angle);
		vec2 dir = vec2(sin(rad), -cos(rad));
		float x = dot(UV * sz - 0.5 * sz, dir);
		float ext = abs(dir.x) * sz.x + abs(dir.y) * sz.y;
		float w = max(width, 1.0) * ps;
		float e = q * q * (3.0 - 2.0 * q);
		float pos = mix(-0.5 * ext - w * 1.8, 0.5 * ext + w * 1.2, e);
		float sh = band(x - pos, w * 0.5, softness);
		if (second_line) {
			sh = max(sh, band(x - (pos - w * 1.1), w * 0.12, softness * 0.5) * 0.8);
		}
		vec3 add = colour.rgb * sh * max(brightness, 0.0) * c.a;
		COLOR = vec4(min(c.rgb + add, vec3(c.a)), c.a);
	}
}
