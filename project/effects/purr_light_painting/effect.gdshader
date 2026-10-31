shader_type canvas_item;
render_mode blend_disabled;

uniform int colour_mode : hint_range(0, 1) = 0;
uniform vec4 colour : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.05, 1.0) = 0.35;
uniform int loops : hint_range(1, 7) = 3;
uniform float width : hint_range(0.5, 30.0) = 4.0;
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform float speed : hint_range(0.0, 3.0) = 0.5;
uniform float trail : hint_range(0.05, 1.0) = 0.5;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }

vec2 path(float s, float asp) {
	float a = float(loops);
	float ph = float(seed) * 0.37;
	return vec2(sin(s * a + ph) * size * 1.4, sin(s * (a + 1.0) + ph * 1.7) * size);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 p = (UV - centre) * vec2(asp, 1.0);
	float head = clip_time * speed * 2.0;
	float span = trail * 6.28318;
	float best = 99.0;
	float bs = 0.0;
	vec2 prev = path(head - span, asp);
	for (int i = 1; i <= 64; i++) {
		float s = head - span + span * float(i) / 64.0;
		vec2 cur = path(s, asp);
		vec2 pa = p - prev;
		vec2 ba = cur - prev;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0000001), 0.0, 1.0);
		float d = length(pa - ba * h);
		if (d < best) {
			best = d;
			bs = float(i) / 64.0;
		}
		prev = cur;
	}
	float px = px_scale / max(tex_size.y, 1.0);
	float dp = best / px;
	float core = smoothstep(width * 0.5 + 1.0, width * 0.5 - 0.5, dp);
	float halo = exp(-dp / (width * 3.0)) * glow;
	float fade = smoothstep(0.0, 0.6, bs);
	vec3 col = colour_mode == 0 ? hsv(vec3(fract(head * 0.05 + bs * 0.5), 0.75, 1.0)) : colour.rgb;
	vec3 add = (col * halo * 0.8 + mix(col, vec3(1.0), 0.7) * core) * fade;
	float la = clamp(max(add.r, max(add.g, add.b)), 0.0, 1.0);
	vec3 base = unp(c);
	float a = c.a + la * (1.0 - c.a);
	COLOR = vec4(min(base * c.a + add, vec3(a)), a);
}
