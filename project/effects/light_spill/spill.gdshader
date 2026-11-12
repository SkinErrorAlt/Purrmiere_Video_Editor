shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float threshold : hint_range(0.0, 1.0) = 0.7;
uniform float colour_bias : hint_range(0.0, 1.0) = 0.5;
uniform float strength : hint_range(0.0, 4.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.25;
uniform float lift : hint_range(0.0, 1.0) = 0.2;
uniform bool light_only = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 soft_add(vec3 base, vec3 add) {
	vec3 room = max(1.0 - base, vec3(0.001));
	return base + room * (1.0 - exp(-max(add, vec3(0.0)) / room));
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec3 rgb = o.a > 0.0001 ? o.rgb / o.a : vec3(0.0);
	vec4 t = texture(TEXTURE, UV);
	vec3 light = t.rgb * t.rgb * t.rgb * 4.0;
	float ambient = t.a * t.a;
	light = max(mix(vec3(dot(light, LUMA)), light, saturation), vec3(0.0));
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float mn = min(rgb.r, min(rgb.g, rgb.b));
	float sat = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	float hi = mix(threshold, 1.0, 0.45) + 0.03;
	float src = smoothstep(threshold, hi, mx) * mix(1.0, smoothstep(0.12, 0.6, sat), colour_bias);
	vec3 gain = light * strength * 1.75 / (ambient + 0.05);
	gain = gain / (1.0 + gain * 0.3);
	float receive = 1.0 - src;
	vec3 add = (rgb * gain + light * strength * lift * 0.5) * receive;
	add += (hash12(UV * 4096.0 + 17.0) - 0.5) / 255.0 * step(0.0005, dot(add, vec3(1.0)));
	vec3 lit = soft_add(clamp(rgb, 0.0, 1.0), add);
	if (light_only) {
		lit = soft_add(vec3(0.0), light * strength * 0.6);
	}
	COLOR = vec4(lit * o.a, o.a);
}
