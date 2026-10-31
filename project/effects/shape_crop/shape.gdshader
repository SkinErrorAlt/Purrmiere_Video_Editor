shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int shape : hint_range(0, 6) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.02, 1.0) = 0.8;
uniform float aspect : hint_range(0.2, 5.0) = 1.4;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform float roundness : hint_range(0.0, 1.0) = 0.2;
uniform float feather : hint_range(0.0, 200.0) = 0.0;
uniform float border : hint_range(0.0, 200.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool invert = false;

float dot2(vec2 v) {
	return dot(v, v);
}

float sd_ellipse(vec2 p, vec2 ab) {
	float k0 = length(p / ab);
	float k1 = length(p / (ab * ab));
	return k1 > 0.00001 ? k0 * (k0 - 1.0) / k1 : -min(ab.x, ab.y);
}

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float sd_hexagon(vec2 p, float r) {
	vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	vec2 q = abs(p);
	q -= 2.0 * min(dot(k.xy, q), 0.0) * k.xy;
	q -= vec2(clamp(q.x, -k.z * r, k.z * r), r);
	return length(q) * sign(q.y);
}

float sd_star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-k1.x, k1.y);
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
	return sqrt(min(dot2(q - vec2(0.0, 1.0)), dot2(q - 0.5 * max(q.x + q.y, 0.0)))) * sign(q.x - q.y);
}

float ndot(vec2 a, vec2 b) {
	return a.x * b.x - a.y * b.y;
}

float sd_rhombus(vec2 p, vec2 b) {
	vec2 q = abs(p);
	float h = clamp(ndot(b - 2.0 * q, b) / max(dot(b, b), 0.00001), -1.0, 1.0);
	float d = length(q - 0.5 * b * vec2(1.0 - h, 1.0 + h));
	return d * sign(q.x * b.y + q.y * b.x - b.x * b.y);
}

void fragment() {
	vec2 res = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 p = (UV - centre) * res;
	float ang = radians(rotation);
	float cs = cos(ang);
	float sn = sin(ang);
	p = vec2(cs * p.x + sn * p.y, -sn * p.x + cs * p.y);
	float big = max(clamp(size, 0.02, 1.0) * 0.5 * min(res.x, res.y), 1.0);
	float asp = clamp(aspect, 0.2, 5.0);
	vec2 half_ext = vec2(big * asp, big);
	float rr = clamp(roundness, 0.0, 1.0) * 0.25 * min(half_ext.x, half_ext.y);
	float squash = min(asp, 1.0);
	vec2 pa = vec2(p.x / asp, p.y);
	float d;
	if (shape == 1) {
		d = sd_ellipse(p, half_ext);
	} else if (shape == 2) {
		float cr = clamp(roundness, 0.0, 1.0) * min(half_ext.x, half_ext.y);
		d = sd_box(p, half_ext, cr);
	} else if (shape == 3) {
		d = (sd_hexagon(pa, max(big - rr, 0.5)) - rr) * squash;
	} else if (shape == 4) {
		vec2 up = vec2(pa.x, -pa.y + big * 0.1);
		d = (sd_star5(up, max(big - rr, 0.5), 0.45) - rr) * squash;
	} else if (shape == 5) {
		float hb = max(big - rr, 0.5);
		vec2 q = vec2(pa.x, -pa.y) / hb * 0.55 + vec2(0.0, 0.55);
		d = (sd_heart(q) * hb / 0.55 - rr) * squash;
	} else if (shape == 6) {
		vec2 b = max(half_ext - vec2(rr), vec2(0.5));
		d = sd_rhombus(p, b) - rr;
	} else {
		d = length(p) - big;
	}
	float sdv = invert ? -d : d;
	float fw = max(feather * ps, 1.0);
	float m = clamp((0.5 - sdv) / fw, 0.0, 1.0);
	if (feather > 0.0) {
		m = m * m * (3.0 - 2.0 * m);
	}
	float bpx = border * ps;
	float bm = bpx > 0.0 ? clamp(bpx + sdv + 0.5, 0.0, 1.0) : 0.0;
	float bk = bm * border_colour.a;
	rgb = mix(rgb, border_colour.rgb, bk);
	float oa = clamp((bk + a * (1.0 - bk)) * m, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
