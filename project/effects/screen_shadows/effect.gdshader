shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec4 screen_colour : source_color = vec4(0.12, 0.72, 0.28, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float ignore : hint_range(0.0, 0.5) = 0.1;
uniform float hue_match : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 20.0) = 3.0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
const vec2 RING[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071), vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

vec3 source_at(vec2 uv) {
	vec4 s = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = clamp(c.a, 0.0, 1.0);
	vec4 o = c;
	if (a < 0.999) {
		vec2 size = max(tex_size, vec2(1.0));
		float r = softness * max(px_scale, 0.0001);
		vec3 src = source_at(UV);
		if (r > 0.25) {
			vec3 sum = src * 2.0;
			for (int i = 0; i < 8; i++) {
				sum += source_at(UV + RING[i] * r / size);
				sum += source_at(UV + RING[i] * r * 0.5 / size);
			}
			src = sum / 18.0;
		}
		float lit = max(dot(screen_colour.rgb, LUMA), 0.02);
		float l = dot(src, LUMA);
		float ratio = l / lit;
		vec3 cs = src / max(src.r + src.g + src.b, 0.0001);
		vec3 ck = screen_colour.rgb / max(screen_colour.r + screen_colour.g + screen_colour.b, 0.0001);
		float tol = mix(0.05, 0.6, hue_match);
		float same = 1.0 - smoothstep(tol, tol + 0.1, distance(cs, ck));
		same = mix(1.0, same, smoothstep(0.02, 0.1, l));
		float dip = clamp((1.0 - ratio - ignore) / max(1.0 - ignore, 0.01), 0.0, 1.0);
		float sh = clamp(dip * strength * same * colour.a, 0.0, 1.0) * (1.0 - a);
		o = vec4(c.rgb + colour.rgb * sh, a + sh);
	}
	COLOR = clamp(o, 0.0, 1.0);
}
