shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, diffuse_burley;


uniform sampler2D clip_tex : source_color, filter_linear;
uniform float refraction : hint_range(0.0, 1.0) = 0.35;
uniform float fresnel_power : hint_range(0.5, 6.0) = 3.0;
uniform float highlight : hint_range(0.0, 2.0) = 0.9;
uniform float tint_amt : hint_range(0.0, 1.0) = 0.14;
uniform vec4 tint : source_color = vec4(0.60, 0.85, 0.74, 1.0);
uniform float dispersion : hint_range(0.0, 1.0) = 0.35;

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : c.rgb;
}

void fragment() {
	float ndv = clamp(abs(dot(normalize(VIEW), NORMAL)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);

	vec2 off = NORMAL.xy * refraction * 0.12;
	float d = dispersion * 0.06 * (0.25 + fres);
	vec2 uvg = clamp(UV + off, vec2(0.0), vec2(1.0));
	vec4 cg = texture(clip_tex, uvg);
	float a = cg.a;
	float r = unpm(texture(clip_tex, clamp(UV + off * (1.0 + d), vec2(0.0), vec2(1.0)))).r;
	float gg = unpm(cg).g;
	float b = unpm(texture(clip_tex, clamp(UV + off * (1.0 - d), vec2(0.0), vec2(1.0)))).b;
	vec3 rgb = vec3(r, gg, b);

	float path = 0.35 + fres * 1.1;
	vec3 absorb = (vec3(1.0) - tint.rgb) * tint_amt * 2.2;
	vec3 glass = rgb * exp(-absorb * path);

	ALBEDO = glass;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = (vec3(fres) + tint.rgb * fres * 0.4) * highlight;
	ALPHA = clamp(a, 0.0, 1.0);
}
