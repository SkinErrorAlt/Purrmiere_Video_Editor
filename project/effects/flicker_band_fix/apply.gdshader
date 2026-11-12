shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int direction = 0;
uniform bool colour = true;

const float BAND_SPAN = 4.0;
const float CHROMA_SPAN = 1.0;

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 band_at(sampler2D tex, ivec2 ax, bool use_colour, int p) {
	vec4 t = texelFetch(tex, ax * p, 0);
	float lum = ((floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 65535.0 - 0.5) * BAND_SPAN;
	vec2 cr = (t.ba - 0.5) * CHROMA_SPAN;
	vec3 chroma = vec3(cr.x, -(0.2126 * cr.x + 0.0722 * cr.y) / 0.7152, cr.y);
	return vec3(lum) + (use_colour ? chroma : vec3(0.0));
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	ivec2 ax = direction == 0 ? ivec2(0, 1) : ivec2(1, 0);
	ivec2 across = ivec2(1) - ax;
	vec2 fs = vec2(textureSize(TEXTURE, 0));
	float count = dot(fs, vec2(ax));
	float pos = clamp(dot(UV, vec2(ax)) * count - 0.5, 0.0, count - 1.0);
	int p0 = int(floor(pos));
	int p1 = min(p0 + 1, int(count) - 1);
	vec3 band = mix(band_at(TEXTURE, ax, colour, p0), band_at(TEXTURE, ax, colour, p1), pos - float(p0));
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 gain = exp2(-band);
	float hi = max(rgb.r, max(rgb.g, rgb.b));
	gain = mix(gain, max(gain, vec3(1.0)), smoothstep(0.95, 0.995, hi));
	COLOR = vec4(to_display(to_linear(rgb) * gain) * c.a, c.a);
}
