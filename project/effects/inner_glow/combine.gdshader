shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
uniform vec4 colour : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float size : hint_range(1.0, 150.0) = 20.0;
uniform float choke : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform int source : hint_range(0, 1) = 0;
uniform int blend : hint_range(0, 3) = 0;

const float DMAX = 256.0;

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

void fragment() {
	float k = max(px_scale, 0.0001);
	vec4 orig = texture(effect_tex, UV);
	float a = orig.a;
	vec3 rgb = a > 0.0001 ? clamp(orig.rgb / a, 0.0, 1.0) : vec3(0.0);
	float d_in = unpack16(texture(TEXTURE, UV).ba) / k;
	float s = max(size, 1.0);
	float solid = s * clamp(choke, 0.0, 0.99);
	float t = clamp((d_in - solid) / max(s - solid, 0.001), 0.0, 1.0);
	float g = 1.0 - t;
	if (source == 1) {
		g = t;
	}
	g = g * g * (3.0 - 2.0 * g);
	g *= strength * colour.a;
	vec3 lit = rgb;
	if (blend == 0) {
		lit = 1.0 - (1.0 - rgb) * (1.0 - colour.rgb);
	} else if (blend == 1) {
		lit = min(rgb + colour.rgb, vec3(1.0));
	} else if (blend == 2) {
		lit = colour.rgb;
	} else {
		lit = rgb * colour.rgb;
	}
	vec3 o = mix(rgb, lit, clamp(g, 0.0, 1.0));
	COLOR = vec4(clamp(o, 0.0, 1.0) * a, a);
}
