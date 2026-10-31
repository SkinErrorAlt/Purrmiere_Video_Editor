shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.42;
uniform float softness : hint_range(0.0, 0.5) = 0.06;
uniform vec4 sky_top : source_color = vec4(0.22, 0.1, 0.4, 1.0);
uniform vec4 sky_mid : source_color = vec4(1.0, 0.42, 0.35, 1.0);
uniform vec4 sky_low : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform vec4 silhouette : source_color = vec4(0.05, 0.03, 0.08, 1.0);
uniform vec2 sun = vec2(0.5, 0.72);
uniform float keep : hint_range(0.0, 1.0) = 0.1;
uniform vec2 tex_size = vec2(1.0, 1.0);

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	float l = lum(s);
	float m = smoothstep(threshold - softness, threshold + softness, l);
	vec3 sky = mix(sky_top.rgb, sky_mid.rgb, smoothstep(0.0, 0.6, UV.y));
	sky = mix(sky, sky_low.rgb, smoothstep(0.55, 0.95, UV.y));
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float d = length((UV - sun) * vec2(asp, 1.0));
	sky += sky_low.rgb * exp(-d * 6.0) * 0.6 + vec3(1.0, 0.95, 0.8) * smoothstep(0.06, 0.04, d);
	sky = mix(sky, sky * (0.6 + 0.8 * l), keep);
	vec3 sil = mix(silhouette.rgb, silhouette.rgb + s * 0.3, keep);
	COLOR = pm(mix(sil, sky, m), c.a);
}
