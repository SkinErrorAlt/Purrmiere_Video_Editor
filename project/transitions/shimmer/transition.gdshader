shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float piece : hint_range(4.0, 120.0) = 16.0;
uniform float drift : hint_range(0.0, 1.0) = 0.8;
uniform float twinkle : hint_range(0.0, 1.0) = 0.7;
uniform int sweep = 0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float WINDOW = 0.45;

float start_of(vec2 cell, vec2 cells) {
	float r = tr_hash(cell + vec2(0.37, 4.1));
	vec2 c = (cell + 0.5) / cells;
	float pos = r;
	if (sweep == 1) {
		pos = c.x;
	} else if (sweep == 2) {
		pos = 1.0 - c.x;
	} else if (sweep == 3) {
		pos = c.y;
	} else if (sweep == 4) {
		pos = 1.0 - c.y;
	} else if (sweep == 5) {
		pos = length(c - 0.5) * 1.41421356;
	}
	float mixed = sweep == 0 ? r : mix(pos, r, 0.3);
	return clamp(mixed, 0.0, 1.0) * (1.0 - WINDOW);
}

vec4 lit(vec4 c, float glint) {
	vec3 rgb = c.rgb * (1.0 + glint * 1.8) + vec3(glint * 0.6) * c.a;
	return vec4(min(rgb, vec3(c.a)), c.a);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float size = max(piece * px_scale, 1.0);
	vec2 cells = frame_px / size;
	vec2 pc = uv * cells;
	vec2 own = floor(pc);
	vec4 top = vec4(0.0);
	float cover = 0.0;
	for (int i = 0; i < 9; i++) {
		vec2 k = own + vec2(float(i == 0 ? 0 : (i - 1) % 3 - 1), float(i == 0 ? 0 : (i - 1) / 3 - 1));
		if (i > 0 && k == own) {
			continue;
		}
		float tk = clamp((p - start_of(k, cells)) / WINDOW, 0.0, 1.0);
		if (tk >= 1.0) {
			continue;
		}
		float sc = 1.0 - 0.65 * smoothstep(0.0, 1.0, tk);
		vec2 rd = tr_hash2(k + vec2(9.1, 2.3)) - 0.5;
		vec2 dir = normalize(rd + vec2(0.0001, -0.0001)) * 0.55 + vec2(0.0, -0.45);
		vec2 centre = k + 0.5 + dir * drift * tk * tk;
		vec2 local = (pc - centre) / sc;
		if (max(abs(local.x), abs(local.y)) <= 0.5) {
			vec2 src = (k + 0.5 + local) / cells;
			float lucky = step(0.55, tr_hash(k + vec2(5.5, 1.7)));
			float glint = twinkle * sin(TR_PI * tk) * (0.25 + 0.75 * lucky);
			float fade = 1.0 - smoothstep(0.35, 1.0, tk);
			top = lit(tk <= 0.0 ? from_at(uv) : from_clamped(src), glint) * fade;
			cover = fade;
			break;
		}
	}
	float tc = clamp((p - start_of(own, cells) - WINDOW * 0.15) / (WINDOW * 0.7), 0.0, 1.0);
	float ramp = smoothstep(0.0, 1.0, tc);
	float glint_to = twinkle * sin(TR_PI * tc) * 0.45 * step(0.6, tr_hash(own + vec2(2.2, 8.8)));
	vec4 under = lit(to_at(uv), glint_to) * ramp;
	vec4 bg = vec4(background.rgb * background.a, background.a);
	float bgw = (1.0 - ramp) * (1.0 - cover);
	return tr_over(tr_over(top, under), bg * bgw);
}

void fragment() {
	COLOR = transition(UV);
}
