shader_type canvas_item;
render_mode blend_disabled;

uniform float yaw : hint_range(-180.0, 180.0) = 0.0;
uniform float pitch : hint_range(-90.0, 90.0) = 0.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;

void fragment() {
	float lon = (UV.x - 0.5) * 6.2831853;
	float lat = (0.5 - UV.y) * 3.14159265;
	vec3 d = vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon));
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
