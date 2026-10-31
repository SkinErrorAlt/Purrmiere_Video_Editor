shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius : hint_range(0.01, 1.0) = 0.4;
uniform float spin : hint_range(-360.0, 360.0) = 0.0;
uniform float tilt : hint_range(-90.0, 90.0) = 15.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform vec2 tex_size;

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 p = (UV - centre) * vec2(sz.x / sz.y, 1.0) / max(radius, 0.0001);
	float r2 = dot(p, p);
	vec4 o = vec4(0.0);
	if (r2 < 1.0) {
		vec3 n = vec3(p.x, -p.y, sqrt(1.0 - r2));
		float b = radians(tilt);
		vec3 m = vec3(n.x, cos(b) * n.y - sin(b) * n.z, sin(b) * n.y + cos(b) * n.z);
		float lon = atan(m.x, m.z) + radians(spin);
		float lat = asin(clamp(m.y, -1.0, 1.0));
		vec2 uv = vec2(fract(lon / 6.2831853 + 0.5), 0.5 - lat / 3.14159265);
		vec4 t = texture(TEXTURE, uv);
		float la = radians(light_angle);
		vec3 L = normalize(vec3(cos(la), sin(la), 0.9));
		float lit = mix(1.0, clamp(dot(n, L), 0.0, 1.0) * 1.15 + 0.1, shading);
		float edge = smoothstep(1.0, 1.0 - 2.0 / (radius * sz.y + 1.0), sqrt(r2));
		o = vec4(min(t.rgb * lit, vec3(t.a)), t.a) * edge;
	}
	COLOR = o;
}
