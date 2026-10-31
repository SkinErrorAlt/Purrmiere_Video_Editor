shader_type canvas_item;
render_mode blend_disabled;

uniform float thickness : hint_range(0.0, 0.5) = 0.05;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform float strength : hint_range(0.0, 2.0) = 0.6;
uniform vec2 tex_size;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	float t = max(thickness, 0.0001);
	float dl = UV.x;
	float dr = 1.0 - UV.x;
	float dt = UV.y;
	float db = 1.0 - UV.y;
	float near = min(min(dl, dr), min(dt, db));
	if (near < t) {
		vec2 n = vec2(0.0);
		if (near == dl) { n = vec2(1.0, 0.0); }
		else if (near == dr) { n = vec2(-1.0, 0.0); }
		else if (near == dt) { n = vec2(0.0, 1.0); }
		else { n = vec2(0.0, -1.0); }
		float rad = radians(light_angle);
		vec2 light = vec2(cos(rad), sin(rad));
		float lit = dot(n, light) * strength * (1.0 - near / t);
		rgb += vec3(lit);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
