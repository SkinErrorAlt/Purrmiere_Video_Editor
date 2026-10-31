shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int kind : hint_range(0, 4) = 1;
uniform float amount : hint_range(0.0, 1.0) = 0.7;
uniform float relief : hint_range(0.0, 1.0) = 0.5;
uniform float texture_scale : hint_range(0.25, 4.0) = 1.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -45.0;
uniform vec4 paper_colour : source_color = vec4(0.97, 0.95, 0.9, 1.0);
uniform int seed : hint_range(0, 9999) = 0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 4; i++) {
		s += w * vnoise(p);
		p = p * 2.1 + vec2(5.3, 1.9);
		w *= 0.5;
	}
	return s / 0.9375;
}

float ridged(vec2 p) {
	float s = 0.0;
	float w = 0.55;
	for (int i = 0; i < 4; i++) {
		float n = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
		s += w * n * n;
		p = p * 2.03 + vec2(9.1, 3.3);
		w *= 0.5;
	}
	return s;
}

float fibres(vec2 p) {
	float f = 0.0;
	for (int i = 0; i < 3; i++) {
		float a = float(i) * 2.1 + 0.4;
		vec2 r = vec2(cos(a) * p.x + sin(a) * p.y, -sin(a) * p.x + cos(a) * p.y);
		f += vnoise(r * vec2(0.08, 0.9));
	}
	return f / 3.0;
}

float height(vec2 p, float sd) {
	if (kind == 1) {
		return ridged(p / 170.0 + sd) * 1.6 + fibres(p + sd) * 0.15;
	}
	if (kind == 2) {
		vec2 q = p / 5.0;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float over = mod(cell.x + cell.y, 2.0);
		float h = over < 0.5 ? sin(f.y * 3.1415926) : sin(f.x * 3.1415926);
		return h * 0.6 + vnoise(p / 3.0 + sd) * 0.3;
	}
	if (kind == 3) {
		return fbm(p / 14.0 + sd) * 0.5 + fibres(p * 0.6 + sd) * 0.4 + sin(p.y / 26.0 * 6.2831853) * 0.18;
	}
	if (kind == 4) {
		return fibres(p + sd) * 0.4 + fbm(p / 60.0 + sd) * 0.4;
	}
	return fibres(p + sd) * 0.5 + vnoise(p * 0.7 + sd) * 0.15;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float k = max(texture_scale, 0.05) * ps;
	vec2 p = UV * sz / k;
	float sd = float(seed) * 17.3 + 2.1;
	float h0 = height(p, sd);
	float hx = height(p + vec2(1.0, 0.0), sd);
	float hy = height(p + vec2(0.0, 1.0), sd);
	vec2 grad = vec2(hx - h0, hy - h0);
	float la = radians(light_angle);
	vec2 ldir = vec2(sin(la), -cos(la));
	float rel = clamp(relief, 0.0, 1.0);
	float gain = kind == 1 ? 9.0 : 4.0;
	float shade = clamp(1.0 + dot(grad, ldir) * gain * rel, 0.35, 1.6);
	vec3 alb = paper_colour.rgb;
	if (kind == 3) {
		alb = mix(alb, vec3(0.74, 0.58, 0.4), 0.75);
	}
	if (kind == 4) {
		alb = mix(alb, vec3(0.9, 0.8, 0.6), 0.55);
		float stain = smoothstep(0.55, 0.8, fbm(UV * sz / (k * 220.0) + sd * 0.5));
		alb = mix(alb, vec3(0.72, 0.56, 0.32), stain * 0.45);
		vec2 e = min(UV, 1.0 - UV) * vec2(sz.x / sz.y, 1.0);
		float burn = 1.0 - smoothstep(0.0, 0.16, min(e.x, e.y) + (fbm(UV * 9.0 + sd) - 0.5) * 0.08);
		alb = mix(alb, vec3(0.45, 0.3, 0.15), burn * 0.6);
	}
	float grain = 0.93 + 0.07 * fibres(p * 1.7 + sd * 0.3);
	vec3 surf = alb * grain * shade;
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 printed = rgb * surf;
	vec3 o = mix(rgb, printed, clamp(amount, 0.0, 1.0));
	COLOR = vec4(clamp(o, 0.0, 1.0) * a, a);
}
