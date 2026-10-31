shader_type canvas_item;
render_mode blend_disabled;

uniform int preset : hint_range(0, 5) = 0;
uniform float thread : hint_range(0.5, 40.0) = 2.5;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform bool twill = true;
uniform vec4 colour_1 : source_color = vec4(0.75, 0.08, 0.1, 1.0);
uniform int count_1 : hint_range(0, 200) = 48;
uniform vec4 colour_2 : source_color = vec4(0.05, 0.12, 0.35, 1.0);
uniform int count_2 : hint_range(0, 200) = 16;
uniform vec4 colour_3 : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform int count_3 : hint_range(0, 200) = 12;
uniform vec4 colour_4 : source_color = vec4(0.95, 0.85, 0.2, 1.0);
uniform int count_4 : hint_range(0, 200) = 4;
uniform float shading : hint_range(0.0, 1.0) = 0.25;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 blend_colour(vec3 base, vec3 over, int how) {
	if (how == 1) { return base * over; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over); }
	if (how == 3) { return mix(2.0 * base * over, 1.0 - 2.0 * (1.0 - base) * (1.0 - over), step(0.5, base)); }
	if (how == 4) { return base + over; }
	if (how == 5) { return (1.0 - 2.0 * over) * base * base + 2.0 * over * base; }
	return over;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, float cov, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(g * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

const vec3 RED = vec3(0.72, 0.06, 0.09);
const vec3 NAVY = vec3(0.04, 0.08, 0.26);
const vec3 BLACK = vec3(0.03, 0.03, 0.04);
const vec3 YELLOW = vec3(0.93, 0.78, 0.16);
const vec3 WHITE = vec3(0.92, 0.92, 0.88);
const vec3 GREEN = vec3(0.04, 0.24, 0.12);
const vec3 AZURE = vec3(0.2, 0.42, 0.75);
const vec3 BLUE = vec3(0.1, 0.18, 0.5);
const vec3 TAN = vec3(0.75, 0.6, 0.4);
const vec3 PINK = vec3(0.92, 0.45, 0.55);
const vec3 ORANGE = vec3(0.95, 0.5, 0.12);
const vec3 SKY = vec3(0.45, 0.72, 0.9);

void stripe(int k, out vec3 col, out float n) {
	if (preset == 0) {
		if (k == 0) { col = RED; n = 28.0; return; }
		if (k == 1) { col = AZURE; n = 6.0; return; }
		if (k == 2) { col = BLACK; n = 8.0; return; }
		if (k == 3) { col = YELLOW; n = 2.0; return; }
		if (k == 4) { col = BLACK; n = 8.0; return; }
		if (k == 5) { col = WHITE; n = 2.0; return; }
		if (k == 6) { col = BLACK; n = 2.0; return; }
		col = RED; n = 6.0; return;
	}
	if (preset == 1) {
		if (k == 0) { col = NAVY; n = 22.0; return; }
		if (k == 1) { col = BLACK; n = 2.0; return; }
		if (k == 2) { col = NAVY; n = 2.0; return; }
		if (k == 3) { col = BLACK; n = 2.0; return; }
		if (k == 4) { col = NAVY; n = 2.0; return; }
		if (k == 5) { col = BLACK; n = 16.0; return; }
		if (k == 6) { col = GREEN; n = 16.0; return; }
		col = BLACK; n = 2.0; return;
	}
	if (preset == 2) {
		if (k == 0) { col = GREEN; n = 8.0; return; }
		if (k == 1) { col = RED; n = 4.0; return; }
		if (k == 2) { col = YELLOW; n = 16.0; return; }
		if (k == 3) { col = BLACK; n = 3.0; return; }
		if (k == 4) { col = WHITE; n = 2.0; return; }
		if (k == 5) { col = BLACK; n = 3.0; return; }
		if (k == 6) { col = BLUE; n = 8.0; return; }
		col = RED; n = 14.0; return;
	}
	if (preset == 3) {
		if (k == 0) { col = WHITE; n = 16.0; return; }
		if (k == 1) { col = BLUE; n = 16.0; return; }
		col = WHITE; n = 0.0; return;
	}
	if (preset == 4) {
		if (k == 0) { col = ORANGE; n = 18.0; return; }
		if (k == 1) { col = PINK; n = 6.0; return; }
		if (k == 2) { col = SKY; n = 10.0; return; }
		if (k == 3) { col = WHITE; n = 3.0; return; }
		if (k == 4) { col = GREEN; n = 12.0; return; }
		if (k == 5) { col = TAN; n = 8.0; return; }
		if (k == 6) { col = YELLOW; n = 4.0; return; }
		col = PINK; n = 14.0; return;
	}
	if (k == 0) { col = colour_1.rgb; n = float(max(count_1, 0)); return; }
	if (k == 1) { col = colour_2.rgb; n = float(max(count_2, 0)); return; }
	if (k == 2) { col = colour_3.rgb; n = float(max(count_3, 0)); return; }
	if (k == 3) { col = colour_4.rgb; n = float(max(count_4, 0)); return; }
	col = vec3(0.0); n = 0.0;
}

float sett_half() {
	float total = 0.0;
	for (int k = 0; k < 8; k++) {
		vec3 col;
		float n;
		stripe(k, col, n);
		total += n;
	}
	return total;
}

vec3 thread_colour(float t) {
	float half_len = max(sett_half(), 1.0);
	float x = mod(t, 2.0 * half_len);
	if (x >= half_len) {
		x = 2.0 * half_len - x;
	}
	float run = 0.0;
	vec3 found = vec3(0.0);
	bool done = false;
	for (int k = 0; k < 8; k++) {
		vec3 col;
		float n;
		stripe(k, col, n);
		if (!done && n > 0.0 && x < run + n) {
			found = col;
			done = true;
		}
		run += n;
	}
	if (!done) {
		vec3 col;
		float n;
		for (int k = 7; k >= 0; k--) {
			stripe(k, col, n);
			if (n > 0.0) {
				found = col;
				break;
			}
		}
	}
	return found;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float th = max(thread * ps, 0.25);
	float rad = radians(angle);
	vec2 d = UV * sz - 0.5 * sz;
	vec2 p = vec2(cos(rad) * d.x + sin(rad) * d.y, -sin(rad) * d.x + cos(rad) * d.y) / th;
	vec2 ti = floor(p);
	vec3 warp = thread_colour(ti.x + 0.5);
	vec3 weft = thread_colour(ti.y + 0.5);
	vec3 cloth;
	float relief = 0.0;
	if (twill) {
		float phase = mod(ti.x + ti.y, 4.0);
		bool show_warp = phase < 2.0;
		cloth = show_warp ? warp : weft;
		vec2 f = p - ti;
		float across = show_warp ? f.x : f.y;
		relief = (0.5 - abs(across - 0.5)) * 2.0;
	} else {
		cloth = mix(warp, weft, 0.5);
		relief = 1.0;
	}
	cloth *= mix(1.0, 0.82 + 0.18 * relief, clamp(shading, 0.0, 1.0) * clamp(th - 1.0, 0.0, 1.0));
	COLOR = mix_in(rgb, a, cloth, 1.0, blend, strength);
}
