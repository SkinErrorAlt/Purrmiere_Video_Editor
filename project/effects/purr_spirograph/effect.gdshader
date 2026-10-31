shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.05, 1.0) = 0.35;
uniform float ring : hint_range(0.1, 0.95) = 0.62;
uniform float pen : hint_range(0.0, 1.5) = 0.8;
uniform float speed : hint_range(0.0, 4.0) = 0.6;
uniform float trail : hint_range(0.05, 1.0) = 0.6;
uniform float width : hint_range(0.5, 20.0) = 2.5;
uniform float glow : hint_range(0.0, 2.0) = 0.8;
uniform int colour_mode : hint_range(0, 1) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.6, 0.85, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }

vec2 spiro(float t) {
	float R = 1.0;
	float r = ring;
	float d = pen * r;
	vec2 p = vec2((R - r) * cos(t) + d * cos((R - r) / r * t), (R - r) * sin(t) - d * sin((R - r) / r * t));
	return p / (R - r + d) * size;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 p = (UV - centre) * vec2(asp, 1.0);
	float head = clip_time * speed * 3.0;
	float span = trail * 25.0;
	float best = 99.0;
	float bs = 0.0;
	vec2 prev = spiro(head - span);
	for (int i = 1; i <= 96; i++) {
		float s = head - span + span * float(i) / 96.0;
		vec2 cur = spiro(s);
		vec2 pa = p - prev;
		vec2 ba = cur - prev;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0000001), 0.0, 1.0);
		float d = length(pa - ba * h);
		if (d < best) {
			best = d;
			bs = float(i) / 96.0;
		}
		prev = cur;
	}
	float px = px_scale / max(tex_size.y, 1.0);
	float dp = best / px;
	float core = smoothstep(width * 0.5 + 1.0, width * 0.5 - 0.5, dp);
	float halo = exp(-dp / (width * 3.0)) * glow;
	vec3 col = colour_mode == 0 ? hsv(vec3(fract(head * 0.02 + bs * 0.3), 0.7, 1.0)) : colour.rgb;
	vec3 add = (col * halo * 0.7 + mix(col, vec3(1.0), 0.5) * core) * smoothstep(0.0, 0.5, bs);
	float la = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	vec3 base = unp(c);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(a)), a);
}
