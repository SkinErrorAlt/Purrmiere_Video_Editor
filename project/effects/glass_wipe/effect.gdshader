shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float band : hint_range(0.01, 0.6) = 0.15;
uniform float refraction : hint_range(0.0, 300.0) = 40.0;
uniform float shine : hint_range(0.0, 1.0) = 0.25;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float aspect = sz.x / sz.y;
	float a = radians(angle);
	vec2 n = vec2(cos(a), -sin(a));
	float s = dot((UV - 0.5) * vec2(aspect, 1.0), n);
	float reach = 0.5 * (aspect + 1.0);
	float edge = mix(-reach, reach + band, progress);
	float t = (s - edge) / max(band, 0.001);
	float inb = step(0.0, t) * step(t, 1.0);
	float bend = sin(clamp(t, 0.0, 1.0) * 3.14159265) * inb;
	vec2 off = n / vec2(aspect, 1.0) * bend * refraction * max(px_scale, 0.0001) / sz.y;
	vec4 c = texture(TEXTURE, clamp(UV - off, vec2(0.0), vec2(1.0)));
	float keep = smoothstep(-0.003, 0.003, s - edge);
	float sh = shine * inb * pow(sin(clamp(t, 0.0, 1.0) * 3.14159265), 6.0);
	vec4 o = c * keep;
	o.rgb = min(o.rgb + vec3(sh) * o.a, vec3(o.a));
	COLOR = o;
}
