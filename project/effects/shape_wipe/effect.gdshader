shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int shape : hint_range(0, 5) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform float border : hint_range(0.0, 200.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float feather : hint_range(0.0, 0.5) = 0.005;
uniform bool invert = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float dot2(vec2 v) {
	return dot(v, v);
}

float sd_star(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	vec2 q = vec2(abs(p.x), p.y);
	q -= 2.0 * max(dot(k1, q), 0.0) * k1;
	q -= 2.0 * max(dot(k2, q), 0.0) * k2;
	q.x = abs(q.x);
	q.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(q, ba) / dot(ba, ba), 0.0, r);
	return length(q - ba * h) * sign(q.y * ba.x - q.x * ba.y);
}

float sd_heart(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	if (q.y + q.x > 1.0) {
		return sqrt(dot2(q - vec2(0.25, 0.75))) - 0.35355339;
	}
	return sqrt(min(dot2(q - vec2(0.0, 1.0)), dot2(q - vec2(0.5 * max(q.x + q.y, 0.0))))) * sign(q.x - q.y);
}

float sd_triangle(vec2 p, float r) {
	float k = 1.7320508;
	vec2 q = vec2(abs(p.x) - r, p.y + r / k);
	if (q.x + k * q.y > 0.0) {
		q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
	}
	q.x -= clamp(q.x, -2.0 * r, 0.0);
	return -length(q) * sign(q.y);
}

float sd_cross(vec2 p, vec2 b) {
	vec2 q = abs(p);
	q = (q.y > q.x) ? q.yx : q.xy;
	vec2 w0 = q - b;
	float k = max(w0.y, w0.x);
	vec2 w = (k > 0.0) ? w0 : vec2(b.y - q.x, -k);
	return sign(k) * length(max(w, vec2(0.0)));
}

float sd_hexagon(vec2 p, float r) {
	vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	vec2 q = abs(p);
	q -= 2.0 * min(dot(k.xy, q), 0.0) * k.xy;
	q -= vec2(clamp(q.x, -k.z * r, k.z * r), r);
	return length(q) * sign(q.y);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float shape_sd(int which, vec2 q) {
	if (which == 1) { return sd_heart(q + vec2(0.0, 0.55)); }
	if (which == 2) { return sd_triangle(q, 1.0); }
	if (which == 3) { return sd_cross(q, vec2(1.0, 0.34)); }
	if (which == 4) { return sd_hexagon(q, 1.0); }
	if (which == 5) { return sd_round_box(q, vec2(1.0), 0.3); }
	return sd_star(q, 1.0, 0.42);
}

float shape_inradius(int which) {
	if (which == 1) { return 0.38; }
	if (which == 2) { return 0.577; }
	if (which == 3) { return 0.48; }
	if (which == 4) { return 1.0; }
	if (which == 5) { return 1.0; }
	return 0.42;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 d = (UV - centre) * sz;
	float rad = radians(rotation);
	float cs = cos(rad);
	float sn = sin(rad);
	vec2 rp = vec2(cs * d.x + sn * d.y, cs * d.y - sn * d.x);
	vec2 q = vec2(rp.x, -rp.y);
	vec2 c0 = centre * sz;
	float far_c = max(max(length(c0), length(sz - c0)), max(length(vec2(c0.x, sz.y - c0.y)), length(vec2(sz.x - c0.x, c0.y))));
	float soft = max(feather, 0.0) * sz.y + 0.75;
	float bpx = border * ps;
	float pr = clamp(progress, 0.0, 1.0);
	float smax = (far_c + soft + bpx + 2.0) / shape_inradius(shape);
	float s = max(pr * smax, 0.001);
	float sd = shape_sd(shape, q / s) * s;
	float side = invert ? (-sd - soft) : sd;
	float keep = smoothstep(-soft, 0.0, side);
	float rim = 0.0;
	if (bpx > 0.0) {
		rim = (1.0 - smoothstep(bpx - 0.75, bpx + 0.75, side)) * clamp(bpx, 0.0, 1.0) * clamp(pr * 20.0, 0.0, 1.0) * clamp(border_colour.a, 0.0, 1.0);
	}
	vec4 pic = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	vec4 outc = mix(pic, vec4(clamp(border_colour.rgb, 0.0, 1.0), 1.0), rim);
	COLOR = outc * clamp(keep, 0.0, 1.0);
}
