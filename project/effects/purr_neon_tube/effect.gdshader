shader_type canvas_item;
render_mode blend_disabled;

uniform float width : hint_range(0.5, 8.0) = 1.5;
uniform float threshold : hint_range(0.0, 0.8) = 0.22;
uniform float glow : hint_range(0.0, 3.0) = 1.2;
uniform float darken : hint_range(0.0, 0.97) = 0.85;
uniform int tube_mode : hint_range(0, 3) = 1;
uniform vec4 tube_colour : source_color = vec4(1.0, 0.25, 0.75, 1.0);
uniform float flicker : hint_range(0.0, 1.0) = 0.1;
uniform float speed : hint_range(0.0, 4.0) = 0.5;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }
float edg(sampler2D t, vec2 uv, vec2 d) { float tl = lum(texture(t, uv - d).rgb); float br = lum(texture(t, uv + d).rgb); float tr = lum(texture(t, uv + vec2(d.x, -d.y)).rgb); float bl = lum(texture(t, uv + vec2(-d.x, d.y)).rgb); float l = lum(texture(t, uv - vec2(d.x, 0.0)).rgb); float r = lum(texture(t, uv + vec2(d.x, 0.0)).rgb); float u = lum(texture(t, uv - vec2(0.0, d.y)).rgb); float b = lum(texture(t, uv + vec2(0.0, d.y)).rgb); float gx = tr + 2.0 * r + br - tl - 2.0 * l - bl; float gy = bl + 2.0 * b + br - tl - 2.0 * u - tr; return length(vec2(gx, gy)); }

float tube(sampler2D tx, vec2 uv, vec2 d) {
	return smoothstep(threshold, threshold + 0.25, edg(tx, uv, d));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = unp(c);
	vec2 d = TX(width);
	float line = tube(TEXTURE, UV, d);
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.3;
		halo += tube(TEXTURE, UV + vec2(cos(a), sin(a)) * TX(width * 4.0), d);
		halo += tube(TEXTURE, UV + vec2(cos(a + 0.4), sin(a + 0.4)) * TX(width * 9.0), d) * 0.5;
	}
	halo /= 12.0;
	vec3 tc = tube_colour.rgb;
	if (tube_mode == 0) {
		tc = col / max(max(col.r, max(col.g, col.b)), 0.05);
	} else if (tube_mode == 1) {
		tc = mix(vec3(1.0, 0.2, 0.7), vec3(0.15, 0.9, 1.0), step(0.5, vn(PX(UV) * 0.006)));
	} else if (tube_mode == 3) {
		tc = hsv(vec3(fract(UV.x * 0.7 + UV.y * 0.4 + clip_time * speed * 0.2), 0.85, 1.0));
	}
	float fl = 1.0 - flicker * h12(vec2(floor(clip_time * 15.0), 1.7)) * step(0.4, h12(vec2(floor(clip_time * 3.0), 8.1)));
	vec3 neon = (tc * (line * 1.1 + halo * glow * 1.6) + vec3(line * 0.5)) * fl;
	neon = clamp(neon, 0.0, 1.0);
	vec3 base = col * (1.0 - darken) * c.a;
	float na = clamp(max(neon.r, max(neon.g, neon.b)), 0.0, 1.0);
	float a = c.a + na * (1.0 - c.a);
	COLOR = vec4(min(base + neon, vec3(a)), a);
}
