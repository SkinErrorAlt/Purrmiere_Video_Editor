shader_type canvas_item;
render_mode blend_disabled;

uniform int source : hint_range(0, 2) = 0;
uniform float threshold : hint_range(0.5, 0.99) = 0.8;
uniform float limit : hint_range(1.0, 2.0) = 1.25;
uniform float power : hint_range(1.0, 3.0) = 1.2;
uniform bool show = false;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 into_709(vec3 c) {
	if (source == 1) {
		return vec3(dot(c, vec3(1.6605, -0.5876, -0.0728)), dot(c, vec3(-0.1246, 1.1329, -0.0083)), dot(c, vec3(-0.0182, -0.1006, 1.1187)));
	}
	if (source == 2) {
		return vec3(dot(c, vec3(1.2249, -0.2247, 0.0)), dot(c, vec3(-0.0420, 1.0419, 0.0)), dot(c, vec3(-0.0197, -0.0786, 1.0979)));
	}
	return c;
}

float compress(float d) {
	float thr = min(threshold, limit - 0.01);
	if (d <= thr) {
		return d;
	}
	float lim = max(limit, thr + 0.01);
	float p = max(power, 1.0);
	float edge = (1.0 - thr) / (lim - thr);
	float s = (lim - thr) / pow(max(pow(edge, -p) - 1.0, 0.000001), 1.0 / p);
	float x = (d - thr) / s;
	return thr + s * x / pow(1.0 + pow(x, p), 1.0 / p);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 lin = into_709(to_linear(rgb));
	float ach = max(lin.r, max(lin.g, lin.b));
	vec3 outl = lin;
	float moved = 0.0;
	if (ach > 0.00001) {
		vec3 d = (ach - lin) / ach;
		vec3 dc = vec3(compress(d.r), compress(d.g), compress(d.b));
		outl = ach - dc * ach;
		moved = max(abs(d.r - dc.r), max(abs(d.g - dc.g), abs(d.b - dc.b)));
	}
	vec3 outc = to_display(max(outl, vec3(0.0)));
	if (show) {
		outc = mix(vec3(dot(outc, vec3(0.2126, 0.7152, 0.0722)) * 0.6), vec3(1.0, 0.1, 0.8), clamp(moved * 4.0, 0.0, 1.0));
	}
	COLOR = vec4(outc * a, a);
}
