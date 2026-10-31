shader_type canvas_item;
render_mode blend_disabled;

uniform float darkness : hint_range(0.0, 1.0) = 0.6;
uniform vec4 moonlight : source_color = vec4(0.55, 0.7, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.7;
uniform float saturation : hint_range(0.0, 1.0) = 0.35;
uniform float sky_darken : hint_range(0.0, 1.0) = 0.5;
uniform float keep_lights : hint_range(0.0, 1.0) = 0.4;
uniform float contrast : hint_range(0.0, 1.0) = 0.3;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = dot(rgb, LUMA);
	float dk = clamp(darkness, 0.0, 1.0);
	float blueness = smoothstep(-0.05, 0.12, rgb.b - max(rgb.r, rgb.g * 0.95));
	float sky = smoothstep(0.4, 0.85, l) * blueness * (1.0 - smoothstep(0.3, 0.75, UV.y));
	float lights = smoothstep(0.82, 0.98, l) * (1.0 - blueness);
	vec3 moon = clamp(moonlight.rgb, 0.0, 1.0);
	moon = moon / max(dot(moon, LUMA), 0.05);
	vec3 c = mix(vec3(l), rgb, clamp(saturation, 0.0, 1.0));
	c = mix(c, vec3(dot(c, LUMA)) * moon, clamp(tint_amount, 0.0, 1.0));
	float gain = exp2(-dk * 1.8);
	c = pow(max(c, vec3(0.0)), vec3(1.0 + dk * 0.3));
	vec3 x = clamp(c, 0.0, 1.0);
	c = mix(c, x * x * (3.0 - 2.0 * x), clamp(contrast, 0.0, 1.0));
	c *= gain;
	c *= 1.0 - clamp(sky_darken, 0.0, 1.0) * sky * 0.75;
	c += moon * vec3(0.0, 0.004, 0.012) * dk;
	vec3 lamp = rgb * mix(vec3(1.0), vec3(1.05, 0.95, 0.82), 0.5);
	c = mix(c, lamp, clamp(keep_lights, 0.0, 1.0) * lights);
	COLOR = vec4(clamp(c, 0.0, 1.0) * a, a);
}
