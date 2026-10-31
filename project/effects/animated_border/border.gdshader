shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform int style = 0;
uniform float width : hint_range(0.002, 0.1) = 0.02;
uniform float roundness : hint_range(0.0, 0.5) = 0.1;
uniform vec4 colour_a : source_color = vec4(0.2, 0.65, 1.0, 1.0);
uniform vec4 colour_b : source_color = vec4(0.95, 0.3, 0.85, 1.0);
uniform float speed : hint_range(-3.0, 3.0) = 0.4;
uniform float glow : hint_range(0.0, 1.0) = 0.5;
uniform float inset : hint_range(0.0, 0.1) = 0.0;
uniform bool keep_whole = false;

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec3 hue_rgb(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k * k * (3.0 - 2.0 * k);
}

float around(vec2 p, vec2 hb) {
	float a = hb.x;
	float b = hb.y;
	float dx = a - abs(p.x);
	float dy = b - abs(p.y);
	float s = 0.0;
	if (dy < dx) {
		s = p.y < 0.0 ? p.x + a : 2.0 * a + 2.0 * b + (a - p.x);
	} else {
		s = p.x > 0.0 ? 2.0 * a + (p.y + b) : 4.0 * a + 2.0 * b + (b - p.y);
	}
	return s;
}

void fragment() {
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 p = (UV - 0.5) * vec2(asp, 1.0);
	float aa = max(length(fwidth(p)) * 0.7071, 0.000001);
	vec2 full = vec2(asp, 1.0) * 0.5;
	float ins = clamp(inset, 0.0, 0.1);
	vec2 hb = max(full - vec2(ins), vec2(0.01));
	float rad = clamp(roundness, 0.0, 0.5) * 2.0 * min(hb.x, hb.y);
	float w = clamp(width, 0.002, 0.1);
	float d = box_sd(p, hb, rad);
	vec4 pic;
	if (keep_whole) {
		vec2 inner = max(hb - vec2(w), vec2(0.005));
		vec2 k = inner / full;
		vec2 suv = p / k / vec2(asp, 1.0) + 0.5;
		pic = texture(effect_tex, clamp(suv, vec2(0.0), vec2(1.0)));
		float inner_r = max(rad - w, 0.0);
		pic *= clamp(0.5 - box_sd(p, inner, inner_r) / aa, 0.0, 1.0);
	} else {
		pic = texture(TEXTURE, UV);
	}
	float outer_cov = clamp(0.5 - d / aa, 0.0, 1.0);
	float band = clamp(0.5 - d / aa, 0.0, 1.0) - clamp(0.5 - (d + w) / aa, 0.0, 1.0);
	band = clamp(band, 0.0, 1.0);
	float perim = 4.0 * (hb.x + hb.y);
	float t = around(p, hb) / max(perim, 0.0001);
	float ph = clip_time * speed;
	vec3 col = colour_a.rgb;
	float bright = 1.0;
	if (style == 0) {
		col = mix(colour_a.rgb, colour_b.rgb, 0.5 + 0.5 * sin(6.2831853 * (t * 2.0 - ph)));
	} else if (style == 1) {
		col = hue_rgb(fract(t - ph));
	} else if (style == 2) {
		float dash = max(w * 3.0, 0.004);
		float cells = max(floor(perim / dash + 0.5), 4.0);
		float m = fract(t * cells - ph * cells * 0.25);
		float on = smoothstep(0.02, 0.06, m) * (1.0 - smoothstep(0.5, 0.54, m));
		col = mix(colour_b.rgb, colour_a.rgb, on);
	} else if (style == 3) {
		bright = 0.55 + 0.45 * sin(6.2831853 * clip_time * max(abs(speed), 0.05) * 2.0);
		col = mix(colour_a.rgb, colour_b.rgb, 0.5 - 0.5 * sin(6.2831853 * clip_time * max(abs(speed), 0.05) * 2.0));
	} else {
		float head = fract(t - ph);
		float tail = exp(-head * 9.0) + exp(-(1.0 - head) * 60.0);
		col = mix(colour_a.rgb * 0.6, colour_b.rgb + vec3(0.25), clamp(tail, 0.0, 1.0));
		bright = 0.7 + 0.6 * clamp(tail, 0.0, 1.0);
	}
	col = clamp(col * bright, 0.0, 1.0);
	float g = clamp(glow, 0.0, 1.0);
	float inner_glow = g * 0.7 * exp(-max(-d - w, 0.0) / max(w * 1.5, 0.002)) * step(d, -w) * outer_cov;
	vec4 c = pic * outer_cov;
	c = vec4(col, 1.0) * inner_glow * bright + c * (1.0 - inner_glow * 0.35);
	c.a = min(c.a, 1.0);
	float ba = band * max(colour_a.a, 0.0);
	c = vec4(col, 1.0) * ba + c * (1.0 - ba);
	COLOR = clamp(c, vec4(0.0), vec4(1.0));
}
