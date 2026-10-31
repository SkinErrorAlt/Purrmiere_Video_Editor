shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform int direction : hint_range(0, 3) = 0;
uniform vec4 bar_colour : source_color = vec4(0.45, 1.0, 0.85, 1.0);
uniform float bar : hint_range(0.0, 40.0) = 5.0;
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 0.5;
uniform float lines : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	float x = UV.x;
	float span = tex_size.x;
	if (direction == 1) { x = UV.y; span = tex_size.y; }
	if (direction == 2) { x = 1.0 - UV.x; }
	if (direction == 3) { x = 1.0 - UV.y; span = tex_size.y; }
	float px = px_scale / max(span, 1.0);
	float pos = (1.0 - pg) * (1.0 + 60.0 * px) - 30.0 * px;
	float d = (x - pos) / px;
	float shown = smoothstep(1.0, -1.0, d);
	float barv = smoothstep(bar * 0.5 + 1.0, bar * 0.5, abs(d)) * step(0.01, bar);
	float gl = exp(-abs(d) / 40.0) * glow;
	float aft = exp(min(d, 0.0) / 160.0) * trail * shown;
	vec2 P = PX(UV);
	float sl = lines * (0.5 + 0.5 * sin((direction == 1 || direction == 3 ? P.x : P.y) * 1.6)) * aft;
	vec3 base = unp(c);
	vec3 tinted = mix(base, bar_colour.rgb * (0.4 + lum(base)), aft * 0.6) * (1.0 - sl * 0.4);
	vec4 pic = vec4(tinted * c.a, c.a) * shown;
	vec3 light = bar_colour.rgb * (gl * 0.6) + mix(bar_colour.rgb, vec3(1.0), 0.5) * barv;
	float la = clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0) * step(0.0001, pg) * step(pg, 0.9999);
	vec4 o = pic + vec4(light * step(0.0001, pg) * step(pg, 0.9999), la) * (1.0 - pic.a);
	o.rgb = min(o.rgb + light * pic.a * 0.5 * step(0.0001, pg), vec3(max(o.a, 0.0)));
	COLOR = pg <= 0.0 ? c : o;
}
