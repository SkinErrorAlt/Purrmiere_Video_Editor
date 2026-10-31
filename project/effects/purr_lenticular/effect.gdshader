shader_type canvas_item;
render_mode blend_disabled;

uniform float ridge : hint_range(2.0, 40.0) = 6.0;
uniform float tilt : hint_range(-1.0, 1.0) = 0.0;
uniform float shine : hint_range(0.0, 1.0) = 0.6;
uniform float rainbow : hint_range(0.0, 1.0) = 0.45;
uniform float shift : hint_range(0.0, 20.0) = 4.0;
uniform float angle : hint_range(-90.0, 90.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec2 P = rot(radians(angle)) * PX(UV);
	float f = fract(P.x / ridge);
	vec2 off = rot(-radians(angle)) * vec2((f - 0.5) * tilt * shift, 0.0);
	vec4 c = texture(TEXTURE, UV + TX(1.0) * off);
	vec3 s = unp(c);
	float cyl = 0.85 + 0.15 * sin(f * 3.14159);
	float hl = exp(-pow(f - (0.5 + tilt * 0.45), 2.0) * 90.0);
	float band = 0.5 + 0.5 * sin(UV.y * 3.0 + UV.x * 2.0 + tilt * 6.0);
	vec3 rb = hsv(vec3(fract(f * 0.3 + tilt * 0.8 + UV.y * 0.3 + UV.x * 0.2), 0.7, 1.0));
	vec3 o = s * cyl;
	o = mix(o, o * 0.6 + rb * 0.6, rainbow * band * 0.6);
	o += vec3(hl * shine * (0.4 + 0.6 * band));
	COLOR = pm(o, c.a);
}
