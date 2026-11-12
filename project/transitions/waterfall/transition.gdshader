shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int run : hint_range(0, 1) = 0;
uniform float threads : hint_range(4.0, 90.0) = 26.0;
uniform float bend : hint_range(0.0, 0.1) = 0.026;
uniform float smear : hint_range(0.0, 1.0) = 0.7;
uniform float foam : hint_range(0.0, 1.0) = 0.65;
uniform float spray : hint_range(0.0, 1.0) = 0.45;
uniform float mist : hint_range(0.0, 1.0) = 0.55;
uniform float uneven : hint_range(0.0, 0.4) = 0.12;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec2 o = run == 1 ? vec2(uv.x, 1.0 - uv.y) : uv;
	float diry = run == 1 ? -1.0 : 1.0;
	float live = 1.0 - smoothstep(0.72, 1.0, p);
	float lead = mix(-0.34, 1.3, smoothstep(0.0, 0.84, p));
	float n = max(threads, 4.0);
	float lx = o.x * n;
	float li = floor(lx);
	float lf = fract(lx);
	float h1 = tr_hash(vec2(li, 3.1) + seed);
	float h2 = tr_hash(vec2(li, 7.7) + seed);
	float lipwave = (tr_fbm(vec2(o.x * 3.4, 7.3)) - 0.5) * 1.4;
	float front = lead + ((h1 - 0.5) * 1.3 + lipwave) * uneven;
	float soft = 2.0 / max(frame_px.y, 1.0);
	float water = smoothstep(-soft, soft, front - o.y);
	float fall = clamp(o.y, 0.0, 1.0);
	float wdt = mix(0.05, 0.3, h1 * h1);
	float centre = 0.5 + (h2 - 0.5) * 0.7;
	float prof = smoothstep(wdt, wdt * 0.25, abs(lf - centre));
	float miss = step(0.3, tr_hash(vec2(li, 15.2) + seed));
	prof *= mix(0.12, 1.0, miss) * mix(0.45, 1.0, h2);
	float brk = tr_fbm(vec2(li * 1.7, o.y * (6.0 + 15.0 * fall) - p * (9.0 + 17.0 * fall)));
	float band = tr_fbm(vec2(o.x * 5.0, 2.1));
	float fil = prof * mix(0.22, 1.0, brk) * mix(0.35, 1.0, band);
	float sm = (0.003 + 0.055 * fall * fall) * smear * live;
	float warp = (lf - centre) * bend * (0.35 + 0.65 * fil) * live;
	vec2 suv = uv + vec2(warp, 0.0);
	vec3 acc = vec3(0.0);
	for (int i = -2; i <= 2; i++) {
		vec2 t = clamp(suv + vec2(0.0, float(i) * sm * 0.5 * diry), vec2(0.0), vec2(1.0));
		acc += to_clamped(t).rgb;
	}
	vec3 wcol = acc * 0.2;
	float aer = clamp(fil * (0.06 + 0.94 * fall) * foam * 1.0, 0.0, 1.0) * live;
	wcol = mix(wcol, mix(vec3(0.88, 0.93, 1.0), vec3(1.0), 0.35), aer * 0.72);
	float sheen = prof * (0.5 + 0.5 * brk) * 0.05 * live;
	wcol += vec3(sheen);
	vec4 col = mix(from_at(uv), vec4(wcol, 1.0), water);
	float dfront = front - o.y;
	float lumps = tr_fbm(vec2(o.x * 24.0, p * 7.0 + li * 0.3));
	float curl = smoothstep(0.055, 0.0, abs(dfront)) * (0.35 + 0.65 * lumps);
	col.rgb = mix(col.rgb, vec3(0.95, 0.97, 1.0), clamp(curl * foam, 0.0, 1.0) * live);
	float lipline = smoothstep(0.04, 0.0, o.y) * water * live * foam;
	col.rgb = mix(col.rgb, vec3(0.97, 0.98, 1.0), clamp(lipline * 0.7, 0.0, 1.0));
	float ahead = smoothstep(0.0, -0.085, dfront) * smoothstep(-0.17, -0.02, dfront);
	vec2 cell = floor(vec2(o.x * 120.0, (o.y + p * 3.2) * 70.0));
	float drops = step(0.87, tr_hash(cell + seed));
	col.rgb += vec3(0.9, 0.95, 1.0) * ahead * drops * spray * 0.8 * live;
	float foot = smoothstep(0.72, 1.0, o.y) * smoothstep(0.45, 0.95, lead);
	float plume = tr_fbm(vec2(o.x * 6.0 - p * 1.2, o.y * 9.0 - p * 5.0));
	col.rgb = mix(col.rgb, vec3(0.93, 0.95, 1.0), clamp(foot * (0.25 + 0.75 * plume) * mist * 0.6, 0.0, 1.0) * live);
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
