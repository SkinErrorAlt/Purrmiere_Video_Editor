shader_type canvas_item;
render_mode blend_disabled;

uniform float angle : hint_range(-180.0, 180.0) = -30.0;
uniform float position : hint_range(-1.5, 1.5) = 0.0;
uniform float width : hint_range(0.02, 1.0) = 0.22;
uniform float strength : hint_range(0.0, 2.0) = 0.7;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform float drift : hint_range(-1.0, 1.0) = 0.05;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec2 h = HN(UV) - vec2(0.5 * tex_size.x / max(tex_size.y, 1.0), 0.5);
	float an = radians(angle);
	float u = dot(h, vec2(cos(an), sin(an))) - position - sin(clip_time * drift) * 0.3;
	float b = u / width + 0.5;
	float soft = 0.05 + softness * 0.3;
	float k = smoothstep(0.0, soft, b) * smoothstep(1.0, 1.0 - soft, b);
	vec3 sp = hsv(vec3(clamp(b, 0.0, 1.0) * 0.8, 0.8, 1.0));
	vec3 add = sp * k * strength;
	vec3 o = 1.0 - (1.0 - s) * (1.0 - clamp(add * 0.8, 0.0, 1.0));
	o += add * 0.15;
	COLOR = pm(o, c.a);
}
