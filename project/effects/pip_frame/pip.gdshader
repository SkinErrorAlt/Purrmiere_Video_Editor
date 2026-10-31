shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec4 source_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 canvas_px = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int corner = 3;
uniform float size : hint_range(0.05, 1.0) = 0.3;
uniform float margin : hint_range(0.0, 0.2) = 0.04;
uniform vec2 position = vec2(0.75, 0.7);
uniform int shape = 0;
uniform float roundness : hint_range(0.0, 0.5) = 0.08;
uniform float border : hint_range(0.0, 0.03) = 0.005;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform int animate = 1;
uniform float anim_time : hint_range(0.05, 2.0) = 0.4;

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec4 over(vec4 top, vec4 under) {
	return top + under * (1.0 - top.a);
}

float ease_out(float x) {
	float v = 1.0 - clamp(x, 0.0, 1.0);
	return 1.0 - v * v * v;
}

float back_out(float x) {
	float v = clamp(x, 0.0, 1.0) - 1.0;
	return 1.0 + 2.70158 * v * v * v + 1.70158 * v * v;
}

float shape_aspect(int s, float own) {
	if (s == 1) {
		return 16.0 / 9.0;
	}
	if (s == 2) {
		return 4.0 / 3.0;
	}
	if (s == 3 || s == 4) {
		return 1.0;
	}
	if (s == 5) {
		return 9.0 / 16.0;
	}
	return own;
}

void fragment() {
	float asp = canvas_px.x / max(canvas_px.y, 1.0);
	vec2 sb = max(source_box.zw, vec2(0.0001));
	float own = sb.x * asp / sb.y;
	float target = max(shape_aspect(shape, own), 0.01);
	vec2 crop = target < own ? vec2(target / own, 1.0) : vec2(1.0, own / target);
	float s = clamp(size, 0.05, 1.0);
	vec2 box = target > asp ? vec2(s * asp, s * asp / target) : vec2(s * target, s);
	vec2 hb = box * 0.5;
	float m = clamp(margin, 0.0, 0.2);
	vec2 centre = position * vec2(asp, 1.0);
	if (corner == 0) {
		centre = vec2(m + hb.x, m + hb.y);
	} else if (corner == 1) {
		centre = vec2(asp - m - hb.x, m + hb.y);
	} else if (corner == 2) {
		centre = vec2(m + hb.x, 1.0 - m - hb.y);
	} else if (corner == 3) {
		centre = vec2(asp - m - hb.x, 1.0 - m - hb.y);
	} else if (corner == 4) {
		centre = vec2(asp * 0.5, 0.5);
	}
	float at = max(anim_time, 0.01);
	float k = animate == 0 ? 1.0 : clamp(min(clip_time, clip_duration - clip_time) / at, 0.0, 1.0);
	float grow = 1.0;
	float fade = 1.0;
	vec2 shift = vec2(0.0);
	if (animate == 1) {
		float right = step(asp * 0.5, centre.x);
		float travel = mix(centre.x + hb.x, asp - centre.x + hb.x, right) + 0.05;
		shift.x = mix(-1.0, 1.0, right) * travel * (1.0 - ease_out(k));
	} else if (animate == 2) {
		grow = max(back_out(k), 0.0);
	} else if (animate == 3) {
		fade = k;
	}
	vec4 c = vec4(0.0);
	if (grow > 0.0005 && fade > 0.0005) {
		vec2 q = UV * vec2(asp, 1.0) - centre - shift;
		vec2 p = q / grow;
		float rad = shape == 4 ? min(hb.x, hb.y) : clamp(roundness, 0.0, 0.5) * 2.0 * min(hb.x, hb.y);
		float d = box_sd(p, hb, rad) * grow;
		float aa = max(length(fwidth(q)) * 0.7071, 0.000001);
		float cov = clamp(0.5 - d / aa, 0.0, 1.0);
		vec2 local = p / box + 0.5;
		vec2 puv = (vec2(1.0) - crop) * 0.5 + clamp(local, vec2(0.0), vec2(1.0)) * crop;
		vec4 pic = texture(effect_tex, puv) * cov;
		float bw = clamp(border, 0.0, 0.03) * grow;
		float ring = bw > 0.0 ? clamp(0.5 - (d - bw) / aa, 0.0, 1.0) * (1.0 - cov) : 0.0;
		float soft = 0.02 + 0.06 * s;
		float ds = box_sd((q - vec2(0.004, 0.012) * s * 3.0) / grow, hb, rad) * grow - bw;
		float sh = clamp(shadow, 0.0, 1.0) * 0.7 * (1.0 - smoothstep(-soft, soft, ds)) * (1.0 - cov);
		c = over(vec4(0.0, 0.0, 0.0, sh), vec4(0.0));
		c = over(vec4(border_colour.rgb, 1.0) * border_colour.a * ring, c);
		c = over(pic, c);
		c *= fade;
	}
	COLOR = c;
}
