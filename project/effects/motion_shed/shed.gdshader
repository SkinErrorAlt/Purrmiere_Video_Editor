shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float life = 0.7;
uniform float amount = 0.4;
uniform float throw_speed = 1.0;
uniform float slow_down = 0.22;
uniform float fall = 0.15;
uniform float scatter = 0.35;
uniform float size = 2.2;
uniform float streak = 1.0;
uniform float spacing = 6.0;

const int TX = 6;
const int TY = 4;

vec3 atlas(sampler2D a, int k, vec2 uv) {
	int t = k - 1;
	vec2 tile = vec2(float(t % TX), float(t / TX));
	vec2 asz = vec2(textureSize(a, 0));
	vec2 tsz = asz / vec2(float(TX), float(TY));
	vec2 p = clamp(uv * tsz, vec2(0.5), tsz - 0.5) + tile * tsz;
	return texture(a, p / asz).rgb;
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	vec2 osz = 1.0 / max(fwidth(UV), vec2(1e-6));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	float range = 64.0 * ps;
	float fps = max(history_fps, 1.0);
	int n = clamp(int(round(life * fps)), 1, TX * TY);
	n = min(n, history_count - 1);
	vec2 p = UV * full;
	float C = max(spacing * ps, 2.0);
	float keep = 1.0 - clamp(slow_down, 0.0, 0.95);
	float grav = fall * ps;
	vec3 acc = vec3(0.0);
	float alpha = 0.0;
	vec4 now_c = texture(effect_tex, UV);
	for (int k = 1; k <= TX * TY; k++) {
		if (k > n) {
			break;
		}
		float age = float(k);
		float G = (1.0 - pow(keep, age)) / max(1.0 - keep, 1e-4);
		vec2 drop = vec2(0.0, grav * age * (age + 1.0) * 0.5);
		vec2 v0 = (atlas(TEXTURE, k, UV).rg - 0.5) * 2.0 * range * throw_speed;
		vec2 e = p - v0 * G - drop;
		vec2 v1 = (atlas(TEXTURE, k, e / full).rg - 0.5) * 2.0 * range * throw_speed;
		e = p - v1 * G - drop;
		vec2 c0 = floor(e / C);
		float lf = age / float(max(n, 1));
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = c0 + vec2(float(i), float(j));
				vec3 h = kit_hash32(cell * 1.31 + vec2(age * 17.17, age * 3.71));
				vec2 ep = (cell + 0.15 + 0.7 * h.xy) * C;
				vec3 at = atlas(TEXTURE, k, ep / full);
				if (h.z >= amount * at.b) {
					continue;
				}
				vec2 v = (at.rg - 0.5) * 2.0 * range * throw_speed;
				float sp = length(v);
				if (sp < 0.5 * ps) {
					continue;
				}
				vec3 h2 = kit_hash32(cell * 0.77 + vec2(age * 5.3, 11.1));
				float ang = (h2.x - 0.5) * scatter * 1.6;
				float mag = 1.0 + (h2.y - 0.5) * scatter * 1.2;
				vec2 vd = vec2(cos(ang) * v.x - sin(ang) * v.y, sin(ang) * v.x + cos(ang) * v.y) * mag;
				vec2 P = ep + vd * G + drop;
				vec2 vn = vd * pow(keep, age) + vec2(0.0, grav * age);
				vec2 tail = P - vn * streak;
				vec2 ab = P - tail;
				float tt = clamp(dot(p - tail, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
				float dist = length(p - (tail + ab * tt));
				float r = size * ps * mix(1.0, 0.45, lf) * mix(0.7, 1.3, h2.z);
				float hit = 1.0 - smoothstep(r * 0.35, r, dist);
				if (hit <= 0.0) {
					continue;
				}
				vec4 sc = history_frame(k, clamp(ep / full, vec2(0.0), vec2(1.0)), now_c);
				vec3 col = sc.a > 0.0001 ? sc.rgb / sc.a : vec3(0.0);
				float life_a = pow(max(1.0 - lf, 1e-4), 1.2) * mix(0.55, 1.0, tt) * smoothstep(0.0, 3.0, age);
				float a = hit * life_a;
				acc += col * a;
				alpha += a;
			}
		}
	}
	vec3 c = alpha > 1e-4 ? acc / alpha : vec3(0.0);
	COLOR = vec4(c, clamp(alpha, 0.0, 1.0));
}
