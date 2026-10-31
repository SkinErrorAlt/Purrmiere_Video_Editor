shader_type canvas_item;
render_mode blend_disabled;

uniform float yaw : hint_range(-180.0, 180.0) = 0.0;
uniform float pitch : hint_range(-90.0, 90.0) = 0.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform float fov : hint_range(10.0, 170.0) = 90.0;
uniform int lens : hint_range(0, 1) = 0;
uniform vec2 tex_size;

void fragment() {
	float aspect = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 n = (UV - 0.5) * 2.0 * vec2(1.0, -1.0 / aspect);
	float hf = radians(fov) * 0.5;
	vec3 d;
	if (lens == 1) {
		float r = length(n);
		float th = r * hf;
		vec2 dir = r > 0.00001 ? n / r : vec2(0.0);
		d = vec3(sin(th) * dir, cos(th));
	} else {
		d = normalize(vec3(n * tan(hf), 1.0));
	}
	float a = radians(yaw);
	float b = radians(pitch);
	float g = radians(roll);
	mat3 ry = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(b), sin(b)), vec3(0.0, -sin(b), cos(b)));
	mat3 rz = mat3(vec3(cos(g), sin(g), 0.0), vec3(-sin(g), cos(g), 0.0), vec3(0.0, 0.0, 1.0));
	d = ry * rx * rz * d;
	vec2 uv = vec2(fract(atan(d.x, d.z) / 6.2831853 + 0.5), 0.5 - asin(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	COLOR = texture(TEXTURE, uv);
}
