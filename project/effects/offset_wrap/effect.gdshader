shader_type canvas_item;
render_mode blend_disabled;

uniform float shift_x : hint_range(-1.0, 1.0) = 0.0;
uniform float shift_y : hint_range(-1.0, 1.0) = 0.0;
uniform float scroll_x : hint_range(-2.0, 2.0) = 0.0;
uniform float scroll_y : hint_range(-2.0, 2.0) = 0.0;
uniform int outside : hint_range(0, 3) = 0;
uniform float seam : hint_range(0.0, 0.3) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;

vec4 fetch(sampler2D tex, vec2 uv) {
	if (outside == 0) {
		return texture(tex, fract(uv + vec2(4.0)));
	}
	if (outside == 1) {
		return texture(tex, 1.0 - abs(1.0 - mod(uv + vec2(4.0), 2.0)));
	}
	if (outside == 3) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
		return texture(tex, uv);
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		vec2 shift = vec2(shift_x + scroll_x * clip_time, shift_y + scroll_y * clip_time);
		vec2 src = UV - shift;
		vec4 col = fetch(TEXTURE, src);
		if (seam > 0.0 && outside == 0) {
			vec2 f = fract(src + vec2(4.0));
			float s = max(seam, 0.0001);
			float wx = smoothstep(s, 0.0, f.x) + smoothstep(1.0 - s, 1.0, f.x);
			float wy = smoothstep(s, 0.0, f.y) + smoothstep(1.0 - s, 1.0, f.y);
			float w = clamp(max(wx, wy), 0.0, 1.0) * 0.5;
			vec4 other = texture(TEXTURE, fract(src + vec2(4.5)));
			col = mix(col, other, w);
		}
		COLOR = mix(base, col, strength);
	}
}
