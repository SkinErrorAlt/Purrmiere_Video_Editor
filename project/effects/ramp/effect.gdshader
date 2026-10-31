shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 start_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 end_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int shape : hint_range(0, 2) = 0;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform float start_at : hint_range(-1.0, 2.0) = 0.0;
uniform float end_at : hint_range(-1.0, 2.0) = 1.0;
uniform int blend : hint_range(0, 4) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	float t;
	if (shape == 1) {
		t = length((UV - centre) * aspect) * 2.0;
	} else if (shape == 2) {
		vec2 d = abs(UV - centre) * aspect * 2.0;
		t = max(d.x, d.y);
	} else {
		float rad = radians(angle);
		vec2 dir = vec2(cos(rad), sin(rad));
		t = dot(UV - centre, dir) + 0.5;
	}
	t = clamp((t - start_at) / max(end_at - start_at, 0.0001), 0.0, 1.0);
	vec3 ramp = mix(start_colour.rgb, end_colour.rgb, t);
	vec3 mixed = ramp;
	if (blend == 1) { mixed = rgb * ramp; }
	else if (blend == 2) { mixed = 1.0 - (1.0 - rgb) * (1.0 - ramp); }
	else if (blend == 3) { mixed = mix(2.0 * rgb * ramp, 1.0 - 2.0 * (1.0 - rgb) * (1.0 - ramp), step(0.5, rgb)); }
	else if (blend == 4) { mixed = rgb + ramp; }
	rgb = mix(rgb, mixed, strength);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
