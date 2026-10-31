shader_type canvas_item;
render_mode blend_disabled;

uniform int grid : hint_range(0, 3) = 0;
uniform float dots : hint_range(0.0, 1.0) = 0.35;
uniform float dot_size : hint_range(2.0, 30.0) = 6.0;
uniform float gap : hint_range(0.0, 40.0) = 8.0;
uniform vec4 gap_colour : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float contrast : hint_range(0.2, 3.0) = 1.3;
uniform float hue : hint_range(0.0, 1.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec2 n = vec2(2.0);
	if (grid == 1) { n = vec2(3.0); }
	if (grid == 2) { n = vec2(2.0, 1.0); }
	if (grid == 3) { n = vec2(4.0); }
	vec2 g = UV * n;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	vec4 c = texture(TEXTURE, f);
	float l = clamp((lum(unp(c)) - 0.5) * contrast + 0.5, 0.0, 1.0);
	float idx = cell.x + cell.y * n.x;
	float h0 = fract(hue + idx * 0.37 + 0.05);
	vec3 sh = hsv(vec3(fract(h0 + 0.5), 0.9, 0.35));
	vec3 md = hsv(vec3(h0, 0.85, 0.95));
	vec3 hi = hsv(vec3(fract(h0 + 0.15), 0.45, 1.0));
	vec3 o = l < 0.33 ? sh : (l < 0.66 ? md : hi);
	vec2 P = PX(UV);
	vec2 dq = rot(0.7854) * P / dot_size;
	float r = sqrt(clamp(1.0 - l, 0.0, 1.0)) * 0.55;
	float dt = smoothstep(r + 0.08, r - 0.08, length(fract(dq) - 0.5));
	o = mix(o, sh * 0.6, dt * dots * step(0.33, l));
	vec2 cs = tex_size / max(px_scale, 0.0001) / n;
	vec2 ed = min(f, 1.0 - f) * cs;
	float gp = 1.0 - smoothstep(gap * 0.5 - 0.5, gap * 0.5 + 0.5, min(ed.x, ed.y));
	gp *= step(0.01, gap);
	o = mix(o, gap_colour.rgb, gp);
	COLOR = pm(o, max(c.a, gp));
}
