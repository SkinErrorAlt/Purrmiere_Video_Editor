shader_type canvas_item;
render_mode blend_disabled;

uniform int method : hint_range(0, 1) = 1;
uniform float reds_cyan : hint_range(-100.0, 100.0) = -15.0;
uniform float reds_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float reds_yellow : hint_range(-100.0, 100.0) = 10.0;
uniform float reds_black : hint_range(-100.0, 100.0) = 0.0;
uniform float yellows_cyan : hint_range(-100.0, 100.0) = 0.0;
uniform float yellows_magenta : hint_range(-100.0, 100.0) = -10.0;
uniform float yellows_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float yellows_black : hint_range(-100.0, 100.0) = 0.0;
uniform float greens_cyan : hint_range(-100.0, 100.0) = 10.0;
uniform float greens_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float greens_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float greens_black : hint_range(-100.0, 100.0) = 0.0;
uniform float cyans_cyan : hint_range(-100.0, 100.0) = 0.0;
uniform float cyans_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float cyans_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float cyans_black : hint_range(-100.0, 100.0) = 0.0;
uniform float blues_cyan : hint_range(-100.0, 100.0) = 25.0;
uniform float blues_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float blues_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float blues_black : hint_range(-100.0, 100.0) = 20.0;
uniform float magentas_cyan : hint_range(-100.0, 100.0) = 0.0;
uniform float magentas_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float magentas_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float magentas_black : hint_range(-100.0, 100.0) = 0.0;
uniform float whites_cyan : hint_range(-100.0, 100.0) = 0.0;
uniform float whites_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float whites_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float whites_black : hint_range(-100.0, 100.0) = 0.0;
uniform float neutrals_cyan : hint_range(-100.0, 100.0) = 0.0;
uniform float neutrals_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float neutrals_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float neutrals_black : hint_range(-100.0, 100.0) = 0.0;
uniform float blacks_cyan : hint_range(-100.0, 100.0) = 0.0;
uniform float blacks_magenta : hint_range(-100.0, 100.0) = 0.0;
uniform float blacks_yellow : hint_range(-100.0, 100.0) = 0.0;
uniform float blacks_black : hint_range(-100.0, 100.0) = 0.0;

vec4 family(int i) {
	if (i == 0) {
		return vec4(reds_cyan, reds_magenta, reds_yellow, reds_black) * 0.01;
	}
	if (i == 1) {
		return vec4(yellows_cyan, yellows_magenta, yellows_yellow, yellows_black) * 0.01;
	}
	if (i == 2) {
		return vec4(greens_cyan, greens_magenta, greens_yellow, greens_black) * 0.01;
	}
	if (i == 3) {
		return vec4(cyans_cyan, cyans_magenta, cyans_yellow, cyans_black) * 0.01;
	}
	if (i == 4) {
		return vec4(blues_cyan, blues_magenta, blues_yellow, blues_black) * 0.01;
	}
	if (i == 5) {
		return vec4(magentas_cyan, magentas_magenta, magentas_yellow, magentas_black) * 0.01;
	}
	if (i == 6) {
		return vec4(whites_cyan, whites_magenta, whites_yellow, whites_black) * 0.01;
	}
	if (i == 7) {
		return vec4(neutrals_cyan, neutrals_magenta, neutrals_yellow, neutrals_black) * 0.01;
	}
	return vec4(blacks_cyan, blacks_magenta, blacks_yellow, blacks_black) * 0.01;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 v = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float mx = max(v.r, max(v.g, v.b));
	float mn = min(v.r, min(v.g, v.b));
	float md = v.r + v.g + v.b - mx - mn;
	float w[9];
	w[0] = (v.r >= v.g && v.r >= v.b) ? mx - md : 0.0;
	w[2] = (v.g > v.r && v.g >= v.b) ? mx - md : 0.0;
	w[4] = (v.b > v.r && v.b > v.g) ? mx - md : 0.0;
	w[1] = (v.b <= v.r && v.b <= v.g) ? md - mn : 0.0;
	w[3] = (v.r < v.g && v.r <= v.b) ? md - mn : 0.0;
	w[5] = (v.g < v.r && v.g < v.b) ? md - mn : 0.0;
	w[6] = clamp((mn - 0.5) * 2.0, 0.0, 1.0);
	w[8] = clamp((0.5 - mx) * 2.0, 0.0, 1.0);
	w[7] = clamp(1.0 - (abs(mx - 0.5) + abs(mn - 0.5)), 0.0, 1.0);
	float k = 1.0 - mx;
	vec3 ink = mx > 0.0001 ? clamp(1.0 - v / mx, 0.0, 1.0) : vec3(0.0);
	vec3 ink_delta = vec3(0.0);
	float k_delta = 0.0;
	for (int i = 0; i < 9; i++) {
		if (w[i] <= 0.0) {
			continue;
		}
		vec4 adj = family(i);
		if (method == 1) {
			ink_delta += w[i] * adj.rgb * ink;
			k_delta += w[i] * adj.a * k;
		} else {
			ink_delta += w[i] * adj.rgb;
			k_delta += w[i] * adj.a;
		}
	}
	vec3 new_ink = clamp(ink + ink_delta, 0.0, 1.0);
	float new_k = clamp(k + k_delta, 0.0, 1.0);
	vec3 outc = (1.0 - new_ink) * (1.0 - new_k);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
