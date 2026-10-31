shader_type canvas_item;
render_mode blend_disabled;

uniform float mist : hint_range(0.0, 1.0) = 0.75;
uniform float blur : hint_range(0.0, 40.0) = 12.0;
uniform vec2 wipe_from = vec2(0.2, 0.45);
uniform vec2 wipe_to = vec2(0.8, 0.55);
uniform float wipe_width : hint_range(0.01, 0.6) = 0.16;
uniform float wipe : hint_range(0.0, 1.0) = 1.0;
uniform int timing : hint_range(0, 1) = 0;
uniform float beads : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 s = unp(c);
	vec3 b = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		b += unp(texture(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(blur)));
		b += unp(texture(TEXTURE, UV + vec2(cos(an + 0.4), sin(an + 0.4)) * TX(blur * 0.5)));
	}
	b /= 16.0;
	vec3 misty = mix(b, vec3(0.85, 0.88, 0.9), mist * 0.45);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float wd = timing == 1 ? clamp(clip_time / 1.2, 0.0, 1.0) : wipe;
	vec2 A = wipe_from * vec2(asp, 1.0);
	vec2 B = mix(wipe_from, wipe_to, wd) * vec2(asp, 1.0);
	vec2 p = UV * vec2(asp, 1.0);
	vec2 pa = p - A;
	vec2 ba = B - A;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	float d = length(pa - ba * h);
	float edge = (vn(p * 40.0) - 0.5) * 0.02;
	float clear = smoothstep(wipe_width * 0.5 + 0.01, wipe_width * 0.5 - 0.005, d + edge) * step(0.001, wd);
	vec2 P = PX(UV);
	float col = floor(P.x / 6.0);
	float drip = step(0.88, h12(vec2(col, 3.0))) * step(0.001, wd);
	float below = UV.y - (A.y + ba.y * clamp((p.x - A.x) / max(abs(ba.x), 0.0001) * sign(ba.x), 0.0, 1.0)) - wipe_width * 0.5;
	float dl = 0.05 + 0.25 * h12(vec2(col, 5.0));
	float dk = drip * step(0.0, below) * step(below, dl) * smoothstep(1.6, 0.4, abs(fract(P.x / 6.0) - 0.5) * 6.0) * step(0.0, p.x - min(A.x, B.x)) * step(p.x, max(A.x, B.x));
	clear = max(clear, dk * 0.8);
	vec2 bp = P / 5.0;
	float bh = h12(floor(bp));
	float bead = step(1.0 - beads * 0.15, bh) * smoothstep(0.45, 0.15, length(fract(bp) - 0.5)) * (1.0 - clear);
	vec3 o = mix(misty, s, clear);
	o = mix(o, b * 0.7 + vec3(0.25), bead * 0.6);
	COLOR = pm(o, c.a);
}
