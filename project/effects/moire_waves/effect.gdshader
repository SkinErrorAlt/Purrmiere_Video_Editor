shader_type canvas_item;
render_mode blend_disabled;

uniform float pitch : hint_range(1.0, 30.0) = 5.0;
uniform float angle_a : hint_range(-180.0, 180.0) = 0.0;
uniform float angle_b : hint_range(-180.0, 180.0) = 4.0;
uniform float rings : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float bend : hint_range(0.0, 1.0) = 0.45;
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 light : source_color = vec4(0.96, 0.96, 0.98, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;

float grating(vec2 world, float deg, float scale, float ring_mix, vec2 mid, float shove) {
	float a = radians(deg);
	vec2 perp = vec2(-sin(a), cos(a));
	float straight = dot(world, perp);
	float radial = length(world - mid);
	float coord = mix(straight, radial, clamp(ring_mix, 0.0, 1.0)) * scale + shove;
	return 0.5 + 0.5 * cos(coord * 6.28318530718);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		vec2 px = max(tex_size, vec2(1.0));
		float ar = px.x / px.y;
		vec2 world = vec2(UV.x * ar, UV.y);
		vec2 mid = vec2(centre.x * ar, centre.y);
		float scale = px.y / max(pitch * max(px_scale, 0.0001), 0.5);
		float lum = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
		float shove = (lum - 0.5) * bend * 6.0;
		float ga = grating(world, angle_a, scale, rings, mid, 0.0);
		float gb = grating(world, angle_b, scale, rings, mid, shove);
		float beat = clamp(ga * gb * 2.0, 0.0, 1.0);
		vec3 shown = mix(ink.rgb, light.rgb, beat);
		COLOR = mix(base, vec4(shown, base.a), strength);
	}
}
