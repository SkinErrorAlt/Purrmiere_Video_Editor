shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float time = 0.0;
uniform float px_scale = 1.0;
#define px_out (px_scale * 32.0)
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float closes_to : hint_range(0.1, 0.9) = 0.42;
uniform float pulse : hint_range(0.0, 1.0) = 0.5;
uniform float heart_rate : hint_range(60.0, 200.0) = 140.0;
uniform float drain : hint_range(0.0, 1.0) = 0.8;

vec3 lin(vec3 c) {
	return c * c;
}

void fragment() {
	vec2 uv_px = fwidth(UV);
	vec4 src = texture(effect_tex, UV);
	vec4 b = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float k0 = b.r * strength;
	float k = 1.0 - (1.0 - k0) * (1.0 - k0);
	if (k0 < 0.004) {
		COLOR = src;
	} else {
		float asp = tex_size.x / max(tex_size.y, 1.0);
		vec2 c = mix(vec2(0.5), b.gb, 0.25 * k);
		vec2 d = vec2((UV.x - c.x) * asp, UV.y - c.y) / (0.5 * sqrt(asp * asp + 1.0));
		float r = length(d);
		float ph = fract(time * heart_rate / 60.0);
		float beat = exp(-pow((ph - 0.08) / 0.05, 2.0)) + 0.6 * exp(-pow((ph - 0.3) / 0.06, 2.0));
		float open = mix(1.25, closes_to, k) * (1.0 - pulse * 0.06 * beat * k);
		float edge = smoothstep(open * 0.55, open, r);
		vec2 px = uv_px * px_out;
		vec2 dir = normalize(vec2(UV - c) + 1e-5);
		float a = max(src.a, 0.0001);
		vec3 acc = vec3(0.0);
		float rs = edge * 28.0 * k;
		for (int i = 0; i < 10; i++) {
			float f = float(i) / 9.0;
			acc += lin(texture(effect_tex, UV - dir * f * rs * px).rgb / a);
		}
		vec3 l = mix(lin(src.rgb / a), acc / 10.0, smoothstep(0.0, 0.6, edge));
		float y = dot(l, vec3(0.2126, 0.7152, 0.0722));
		l = mix(l, vec3(y), drain * edge);
		float dark = edge * (0.85 + 0.25 * pulse * beat) * k * 1.1;
		l *= 1.0 - clamp(dark, 0.0, 0.95);
		l *= 1.0 + 0.06 * k * (1.0 - edge);
		COLOR = vec4(sqrt(clamp(l, 0.0, 1.0)) * a, a);
	}
}
