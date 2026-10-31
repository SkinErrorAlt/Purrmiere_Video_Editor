shader_type canvas_item;
render_mode blend_disabled;

uniform float contrast : hint_range(0.5, 3.0) = 1.6;
uniform float blinds : hint_range(0.0, 1.0) = 0.6;
uniform int slats : hint_range(2, 40) = 12;
uniform float angle : hint_range(-80.0, 80.0) = -20.0;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = lum(unp(c));
	l = clamp((l - 0.45) * contrast + 0.45, 0.0, 1.0);
	vec2 h = HN(UV);
	vec2 q = rot(radians(angle)) * h;
	float f = fract(q.y * float(slats) * 0.6);
	float sh = smoothstep(0.45 - softness * 0.3, 0.45 + softness * 0.3, f);
	float win = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.6, UV.x);
	l *= 1.0 - blinds * (1.0 - sh) * 0.75 * win;
	vec2 P = PX(UV);
	l += (h12(floor(P) + floor(clip_time * 24.0) * 7.0) - 0.5) * grain * 0.2;
	vec2 vq = UV - 0.5;
	l *= 1.0 - vignette * smoothstep(0.25, 0.8, length(vq * vec2(1.2, 1.0)));
	COLOR = pm(vec3(clamp(l, 0.0, 1.0)), c.a);
}
