shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;
#define px_out (px_scale * 32.0)
uniform float blur : hint_range(0.0, 40.0) = 16.0;
uniform float focus_size : hint_range(0.05, 0.8) = 0.22;
uniform float rack_time : hint_range(0.05, 1.0) = 0.3;
uniform float stay : hint_range(0.3, 1.9) = 1.6;
uniform float darken : hint_range(0.0, 1.0) = 0.2;

vec3 lin(vec3 c) {
	return c * c;
}

vec4 block(sampler2D t, int k) {
	ivec2 sz = textureSize(t, 0);
	return texelFetch(t, ivec2(clamp(int((float(k) + 0.5) / 4.0 * float(sz.x)), 0, sz.x - 1), 0), 0);
}

void fragment() {
	vec2 uv_px = fwidth(UV);
	vec4 src = texture(effect_tex, UV);
	vec4 b0 = block(TEXTURE, 0);
	float s = floor(b0.r * 63.0 + 0.5);
	float fps = max(history_fps, 1.0);
	float span = min(stay * fps, 54.0);
	if (b0.r > 0.995 || s >= span || blur <= 0.0) {
		COLOR = src;
	} else {
		float t = s / fps;
		float rin = smoothstep(0.0, max(rack_time, 0.02), t);
		float rout = 1.0 - smoothstep(span * 0.6, span, s);
		float amt = rin * rout * mix(0.7, 1.0, b0.g);
		vec2 cur = block(TEXTURE, 1).rg;
		vec2 f = mix(b0.ba, cur, 0.75);
		float asp = tex_size.x / max(tex_size.y, 1.0);
		float d = length(vec2((UV.x - f.x) * asp, UV.y - f.y));
		float coc = smoothstep(focus_size * 0.5, focus_size * 1.6, d) * amt;
		float r = coc * blur * px_out;
		float a = max(src.a, 0.0001);
		vec3 l;
		if (r < 0.4) {
			l = lin(src.rgb / a);
		} else {
			vec2 px = uv_px;
			vec3 acc = vec3(0.0);
			float wsum = 0.0;
			for (int i = 0; i < 32; i++) {
				float rr = sqrt((float(i) + 0.5) / 32.0);
				float ang = float(i) * 2.39996;
				vec3 c = lin(texture(effect_tex, UV + vec2(cos(ang), sin(ang)) * rr * r * px).rgb / a);
				float w = 1.0 + 4.0 * smoothstep(0.35, 0.9, dot(c, vec3(0.3, 0.55, 0.15)));
				acc += c * w;
				wsum += w;
			}
			l = acc / wsum;
		}
		l *= 1.0 - darken * coc * 0.6;
		COLOR = vec4(sqrt(clamp(l, 0.0, 1.0)) * a, a);
	}
}
