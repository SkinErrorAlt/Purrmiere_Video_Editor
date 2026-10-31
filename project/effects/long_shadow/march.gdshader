shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform float shadow_length : hint_range(0.0, 2000.0) = 400.0;
uniform float fade : hint_range(0.0, 1.0) = 0.5;
uniform bool fine_stage = true;

void fragment() {
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	vec2 size = max(tex_size, vec2(1.0));
	float len_px = max(shadow_length * px_scale, 0.0);
	float coarse = len_px / 32.0;
	float stride = fine_stage ? coarse / 32.0 : coarse;
	float per_px = fade / max(len_px, 0.0001);
	float best = 0.0;
	for (int i = 0; i < 32; i++) {
		float d = float(i) * stride;
		vec2 uv = UV - dir * d / size;
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
			float v = texture(TEXTURE, uv).a;
			best = max(best, v - per_px * d);
		}
	}
	COLOR = vec4(clamp(best, 0.0, 1.0));
}
