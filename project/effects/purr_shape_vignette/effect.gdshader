shader_type canvas_item;
render_mode blend_disabled;

uniform int shape : hint_range(0, 5) = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.1, 2.0) = 0.75;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform int mode : hint_range(0, 2) = 0;
uniform vec4 colour : source_color = vec4(0.12, 0.05, 0.14, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform vec2 tex_size = vec2(1.0, 1.0);

float sde(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

float heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return length(p - vec2(0.25, 0.75)) - 0.353553;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

float tri_ear(vec2 p, vec2 at, float w, float h) {
	vec2 q = p - at;
	float y = -q.y;
	float side = (abs(q.x) - w * (1.0 - y / h)) * h / sqrt(h * h + w * w);
	return max(-y, max(side, y - h));
}

float sd(vec2 p, float asp) {
	if (shape == 0) {
		return heart(vec2(p.x, -p.y) * 0.75 + vec2(0.0, 0.45)) / 0.75;
	}
	if (shape == 1) {
		vec2 q = p * 0.85;
		float d = sde(q - vec2(0.0, 0.2), vec2(0.42, 0.34));
		d = min(d, sde(q - vec2(-0.5, -0.24), vec2(0.15, 0.19)));
		d = min(d, sde(q - vec2(-0.18, -0.52), vec2(0.16, 0.2)));
		d = min(d, sde(q - vec2(0.18, -0.52), vec2(0.16, 0.2)));
		d = min(d, sde(q - vec2(0.5, -0.24), vec2(0.15, 0.19)));
		return d / 0.85;
	}
	if (shape == 2) {
		float an = atan(-p.y, p.x) - 1.5708;
		float k = abs(fract(an / 1.256637) - 0.5) * 2.0;
		return (length(p) - mix(0.5, 1.0, pow(k, 1.5))) * 0.6;
	}
	if (shape == 3) {
		float d = sde(p - vec2(0.0, 0.12), vec2(0.88, 0.76));
		d = min(d, tri_ear(p, vec2(-0.5, -0.35), 0.32, 0.6));
		d = min(d, tri_ear(p, vec2(0.5, -0.35), 0.32, 0.6));
		return d;
	}
	if (shape == 5) {
		vec2 b = vec2(asp * 0.5, 0.5) / 0.55;
		vec2 q = abs(p) - b + 0.3;
		return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.3;
	}
	return length(p) - 1.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0) / (size * 0.55);
	float d = sd(q, asp);
	float k = smoothstep(-softness * 0.6 - 0.005, softness * 0.6 + 0.005, d) * strength;
	vec4 o = c;
	if (mode == 0) {
		o = vec4(c.rgb * (1.0 - k), c.a);
	} else if (mode == 1) {
		o = mix(c, vec4(colour.rgb, 1.0), k * colour.a);
	} else {
		o = c * (1.0 - k);
	}
	COLOR = o;
}
