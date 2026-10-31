shader_type canvas_item;
render_mode blend_disabled;

uniform float width : hint_range(2.0, 300.0) = 36.0;
uniform int palette : hint_range(0, 3) = 0;
uniform float flake : hint_range(0.5, 8.0) = 2.0;
uniform float twinkle : hint_range(0.0, 4.0) = 1.5;
uniform float stars : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec3 hsv(vec3 c) { vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0); return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 S = tex_size / max(px_scale, 0.0001);
	vec2 P = UV * S;
	vec2 e = min(P, S - P);
	float ed = min(e.x, e.y);
	float band = 1.0 - smoothstep(width - softness * width * 0.5 - 0.5, width + 0.5, ed);
	vec2 cl = floor(P / flake);
	float h = h12(cl);
	float tw = pow(0.5 + 0.5 * sin(clip_time * twinkle * 6.0 + h * 60.0), 6.0);
	vec3 base = vec3(0.85, 0.65, 0.25);
	if (palette == 1) {
		base = vec3(0.78, 0.8, 0.84);
	} else if (palette == 2) {
		base = vec3(0.9, 0.6, 0.55);
	} else if (palette == 3) {
		base = hsv(vec3(fract(h * 3.0 + (P.x + P.y) / (S.x + S.y)), 0.6, 0.9));
	}
	vec3 g = base * (0.45 + 0.4 * h12(cl + 3.0)) + vec3(tw * 0.8);
	vec2 sc = floor(P / 24.0);
	vec2 sf = fract(P / 24.0) - 0.5;
	float sh = h12(sc + floor(clip_time * 3.0) * 1.3);
	float star = step(0.97, sh) * stars * (smoothstep(0.06, 0.0, abs(sf.x)) + smoothstep(0.06, 0.0, abs(sf.y))) * smoothstep(0.5, 0.0, length(sf));
	g += vec3(star);
	vec4 gl = vec4(clamp(g, 0.0, 1.0), 1.0);
	COLOR = mix(c, gl, band);
}
