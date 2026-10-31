shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 shadows : source_color = vec4(0.2, 0.2, 0.24, 1.0);
uniform vec4 midtones : source_color = vec4(0.55, 0.5, 0.42, 1.0);
uniform vec4 highlights : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform bool pin = true;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 gain_for(vec3 cast) {
	float l = dot(cast, LUMA);
	return clamp(vec3(l) / max(cast, vec3(0.004)), vec3(0.25), vec3(4.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = dot(rgb, LUMA);
	float ls = clamp(dot(shadows.rgb, LUMA), 0.002, 0.996);
	float lm = clamp(dot(midtones.rgb, LUMA), ls + 0.001, 0.997);
	float lh = clamp(dot(highlights.rgb, LUMA), lm + 0.001, 0.998);
	vec3 gs = gain_for(shadows.rgb);
	vec3 gm = gain_for(midtones.rgb);
	vec3 gh = gain_for(highlights.rgb);
	vec3 g;
	if (l <= ls) {
		g = pin ? mix(vec3(1.0), gs, smoothstep(0.0, ls, l)) : gs;
	} else if (l <= lm) {
		g = mix(gs, gm, (l - ls) / (lm - ls));
	} else if (l <= lh) {
		g = mix(gm, gh, (l - lm) / (lh - lm));
	} else {
		g = pin ? mix(gh, vec3(1.0), smoothstep(lh, 1.0, l)) : gh;
	}
	COLOR = vec4(clamp(rgb * g, 0.0, 1.0) * a, a);
}
