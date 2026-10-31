shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int count : hint_range(1, 16) = 6;
uniform float distance : hint_range(0.0, 200.0) = 12.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float decay : hint_range(0.0, 1.0) = 0.7;
uniform bool ring = true;

void fragment() {
	vec4 sum = texture(TEXTURE, UV);
	float wsum = 1.0;
	float w = 1.0;
	vec2 px = 1.0 / tex_size;
	float d = distance * px_scale;
	for (int i = 1; i <= 16; i++) {
		if (i > count) {
			break;
		}
		w *= decay;
		vec2 off;
		if (ring) {
			float a = radians(angle) + float(i - 1) * 6.28318530718 / float(count);
			off = vec2(cos(a), sin(a)) * d;
		} else {
			float a = radians(angle);
			off = vec2(cos(a), sin(a)) * d * float(i);
		}
		sum += texture(TEXTURE, clamp(UV + off * px, vec2(0.0), vec2(1.0))) * w;
		wsum += w;
	}
	COLOR = sum / wsum;
}
