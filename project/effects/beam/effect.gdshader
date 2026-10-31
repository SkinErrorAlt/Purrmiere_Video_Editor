shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 start = vec2(0.15, 0.7);
uniform vec2 end = vec2(0.85, 0.3);
uniform float length : hint_range(0.0, 1.0) = 1.0;
uniform float travel : hint_range(0.0, 1.0) = 0.5;
uniform float start_thickness : hint_range(0.0, 200.0) = 8.0;
uniform float end_thickness : hint_range(0.0, 200.0) = 8.0;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float glow_size : hint_range(0.0, 10.0) = 2.5;
uniform bool on_original = true;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 a = start * sz;
	vec2 b = end * sz;
	vec2 P = UV * sz;
	float head = travel * (1.0 + length);
	float t0 = clamp(head - length, 0.0, 1.0);
	float t1 = clamp(head, 0.0, 1.0);
	vec2 ab = b - a;
	float t = clamp(dot(P - a, ab) / max(dot(ab, ab), 0.0001), t0, t1);
	float d = distance(P, a + ab * t);
	float th = max(mix(start_thickness, end_thickness, t) * 0.5 * ps, 0.25);
	float vis = step(0.00001, t1 - t0);
	float k = smoothstep(th, th * (1.0 - softness) - 0.5, d) * vis;
	float g = glow_size > 0.0 ? exp(-max(d - th * 0.5, 0.0) / (th * glow_size)) * vis : 0.0;
	vec4 base = on_original ? c : vec4(0.0);
	vec3 add = core.rgb * core.a * k + glow.rgb * glow.a * g * (1.0 - k);
	float ga = clamp(max(k * core.a, g * glow.a), 0.0, 1.0);
	vec3 rgb = base.rgb + add;
	float oa = max(base.a, ga);
	COLOR = vec4(min(rgb, vec3(oa)), oa);
}
