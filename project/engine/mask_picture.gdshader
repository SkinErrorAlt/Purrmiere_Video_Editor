shader_type canvas_item;
render_mode blend_disabled;

// A picture used as a mask. The plate covers the whole frame; the picture sits in a box (centre and size in frame
// units, turned by rotation) and one of its channels, stretched between low and high, becomes the mask.
uniform vec4 box = vec4(0.5, 0.5, 0.5, 0.5);
uniform float rotation = 0.0;
uniform float aspect = 1.0;
uniform int channel = 0;
uniform float low = 0.0;
uniform float high = 1.0;

void fragment() {
	vec2 d = UV - box.xy;
	d.x *= aspect;
	float c = cos(-rotation);
	float s = sin(-rotation);
	d = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
	d.x /= aspect;
	vec2 local = d / max(box.zw, vec2(0.0001)) + 0.5;
	float on = step(0.0, local.x) * step(local.x, 1.0) * step(0.0, local.y) * step(local.y, 1.0);
	vec4 px = texture(TEXTURE, clamp(local, vec2(0.0), vec2(1.0)));
	float v = dot(px.rgb, vec3(0.2126, 0.7152, 0.0722)) * px.a;
	if (channel == 1) {
		v = px.a;
	} else if (channel == 2) {
		v = px.r * px.a;
	} else if (channel == 3) {
		v = px.g * px.a;
	} else if (channel == 4) {
		v = px.b * px.a;
	}
	v = clamp((v - low) / max(high - low, 0.0001), 0.0, 1.0);
	COLOR = vec4(vec3(1.0), v * on);
}
