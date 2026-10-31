shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-60.0, 60.0) = 12.0;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float streak_length : hint_range(1.0, 400.0) = 40.0;
uniform float thickness : hint_range(0.5, 10.0) = 1.5;
uniform vec4 colour : source_color = vec4(0.8, 0.85, 0.92, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 2;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pos = UV * sz;
	float rad = radians(angle);
	vec2 fall = vec2(sin(rad), cos(rad));
	vec2 side_dir = vec2(cos(rad), -sin(rad));
	float along = dot(pos, fall);
	float across = dot(pos, side_dir);
	vec2 skey = floor(hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 997.0);
	float clear = 1.0;
	for (int li = 0; li < 3; li++) {
		float fl = float(li);
		float depth = 1.0 - fl * 0.28;
		float cw = (30.0 - fl * 8.0) * ps;
		float len = max(streak_length * ps * depth, 1.0);
		float ch = len + cw * 3.0;
		float vel = sz.y * 1.6 * speed * (0.45 + 0.55 * depth);
		float halfw = 0.5 * thickness * ps * depth;
		float edge_w = max(halfw, 0.5);
		float col = floor(across / cw);
		float colkey = mod(col, 1024.0);
		float col_off = hash12(vec2(colkey, fl * 31.7) + skey) * ch;
		float y = along - mod(clip_time * vel, ch * 1024.0) + col_off;
		float row = floor(y / ch);
		float fy = y - row * ch;
		float lx = across - col * cw;
		for (int rr = 0; rr < 2; rr++) {
			float ri = row - float(rr);
			vec3 h = hash32(vec2(colkey, mod(ri, 1024.0)) + vec2(fl * 1031.0, 0.0) + skey);
			if (h.x < amount) {
				float x0 = (0.25 + 0.5 * h.y) * cw;
				float y0 = h.z * ch;
				float ly = fy + float(rr) * ch;
				float dy = ly - clamp(ly, y0, y0 + len);
				float dx = lx - x0;
				float dist = length(vec2(dx, dy));
				float line_cov = 1.0 - smoothstep(edge_w - 0.75, edge_w + 0.75, dist);
				line_cov *= clamp(halfw * 2.0, 0.0, 1.0);
				float head = clamp((ly - y0) / len, 0.0, 1.0);
				float bb = line_cov * (0.25 + 0.75 * head) * (0.4 + 0.6 * depth) * (0.6 + 0.4 * h.y);
				clear *= 1.0 - clamp(bb, 0.0, 1.0);
			}
		}
	}
	float cov = (1.0 - clear) * clamp(opacity, 0.0, 1.0) * colour.a;
	COLOR = mix_in(rgb, a, colour.rgb, cov, blend, strength);
}
