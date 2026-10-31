shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 target : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.3;
uniform float softness : hint_range(0.0, 1.0) = 0.2;
uniform float hue_shift : hint_range(-180.0, 180.0) = 0.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float grey_the_rest : hint_range(0.0, 1.0) = 0.0;

vec3 to_hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.00001) {
		if (mx == c.r) { h = mod((c.g - c.b) / d, 6.0); }
		else if (mx == c.g) { h = (c.b - c.r) / d + 2.0; }
		else { h = (c.r - c.g) / d + 4.0; }
		h /= 6.0;
	}
	return vec3(h, mx > 0.00001 ? d / mx : 0.0, mx);
}

vec3 to_rgb(vec3 hsv) {
	vec3 k = mod(vec3(5.0, 3.0, 1.0) + hsv.x * 6.0, 6.0);
	return hsv.z - hsv.z * hsv.y * max(vec3(0.0), min(min(k, 4.0 - k), vec3(1.0)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 hsv = to_hsv(clamp(rgb, 0.0, 1.0));
	vec3 thsv = to_hsv(clamp(target.rgb, 0.0, 1.0));
	float dh = abs(fract(hsv.x - thsv.x + 0.5) - 0.5) * 2.0;
	float soft = max(softness, 0.0001);
	float hit = 1.0 - smoothstep(max(tolerance - soft, 0.0), tolerance + soft, dh);
	hit *= smoothstep(0.03, 0.15, hsv.y);
	vec3 moved = to_rgb(vec3(fract(hsv.x + hue_shift / 360.0), clamp(hsv.y * saturation, 0.0, 1.0), hsv.z * brightness));
	vec3 grey = vec3(dot(rgb, vec3(0.2126, 0.7152, 0.0722)));
	vec3 rest = mix(rgb, grey, grey_the_rest);
	rgb = mix(rest, moved, hit);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
