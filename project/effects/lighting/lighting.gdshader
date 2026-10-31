shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 light_position = vec2(0.3, 0.3);
uniform float height : hint_range(0.01, 2.0) = 0.3;
uniform float radius : hint_range(0.05, 3.0) = 1.0;
uniform vec4 colour : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.2;
uniform float ambient : hint_range(0.0, 1.0) = 0.2;
uniform float bump : hint_range(0.0, 10.0) = 2.0;
uniform float shine : hint_range(0.0, 1.0) = 0.3;
uniform bool spot = false;
uniform float spot_angle : hint_range(1.0, 90.0) = 30.0;
uniform vec2 spot_target = vec2(0.6, 0.7);
uniform float spot_softness : hint_range(0.0, 1.0) = 0.3;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float lum_at(vec4 c) {
	return c.a > 0.0001 ? dot(clamp(c.rgb / c.a, 0.0, 1.0), LUMA) : 0.0;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.x / size.y;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 d = vec2(max(px_scale, 0.5) * 1.5) / size;
	float lx0 = lum_at(texture(TEXTURE, clamp(UV - vec2(d.x, 0.0), vec2(0.0), vec2(1.0))));
	float lx1 = lum_at(texture(TEXTURE, clamp(UV + vec2(d.x, 0.0), vec2(0.0), vec2(1.0))));
	float ly0 = lum_at(texture(TEXTURE, clamp(UV - vec2(0.0, d.y), vec2(0.0), vec2(1.0))));
	float ly1 = lum_at(texture(TEXTURE, clamp(UV + vec2(0.0, d.y), vec2(0.0), vec2(1.0))));
	vec3 n = normalize(vec3(-(lx1 - lx0) * bump, -(ly1 - ly0) * bump, 1.0));
	vec2 pos = UV * vec2(aspect, 1.0);
	vec2 lxy = light_position * vec2(aspect, 1.0);
	float h = max(height, 0.01);
	vec3 to_l = vec3(lxy - pos, h);
	float dist = max(length(to_l), 0.0001);
	vec3 l = to_l / dist;
	float lambert = max(dot(n, l), 0.0);
	float plane = length(lxy - pos) / max(radius, 0.05);
	float att = clamp(1.0 - plane * plane, 0.0, 1.0);
	att *= att;
	float cone = 1.0;
	if (spot) {
		vec3 axis = vec3(spot_target * vec2(aspect, 1.0) - lxy, -h);
		axis = axis / max(length(axis), 0.0001);
		float outer = radians(clamp(spot_angle, 1.0, 90.0));
		float inner = outer * (1.0 - clamp(spot_softness, 0.0, 1.0) * 0.95);
		float cosang = dot(-l, axis);
		float co = cos(outer);
		float ci = cos(inner);
		cone = clamp((cosang - co) / max(ci - co, 0.0001), 0.0, 1.0);
		cone = cone * cone * (3.0 - 2.0 * cone);
	}
	vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, hv), 0.0), 24.0) * shine;
	vec3 light = colour.rgb * colour.a * intensity * att * cone;
	vec3 outc = rgb * (ambient + light * lambert) + light * spec;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
