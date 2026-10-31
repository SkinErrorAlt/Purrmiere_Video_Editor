shader_type canvas_item;
render_mode blend_disabled;

uniform float radius : hint_range(0.0, 400.0) = 36.0;
uniform float border : hint_range(0.0, 80.0) = 8.0;
uniform int style : hint_range(0, 2) = 1;
uniform vec4 colour_a : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform vec4 colour_b : source_color = vec4(0.2, 0.85, 1.0, 1.0);
uniform float spin : hint_range(-4.0, 4.0) = 0.25;
uniform float glow : hint_range(0.0, 1.0) = 0.4;
uniform float shade : hint_range(0.0, 1.0) = 0.3;
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 p = (UV - 0.5) * sz;
	float r = min(radius * px_scale, min(sz.x, sz.y) * 0.5);
	float d = box(p, sz * 0.5, r);
	float mask = 1.0 - smoothstep(-0.75, 0.25, d);
	float bw = border * px_scale;
	float a = atan(p.y * sz.x / sz.y, p.x) / 6.2831853 + 0.5 + clip_time * spin;
	vec3 bc = colour_a.rgb;
	if (style == 1) {
		bc = mix(colour_a.rgb, colour_b.rgb, 0.5 + 0.5 * cos(a * 6.2831853));
	} else if (style == 2) {
		bc = hue(fract(a));
	}
	float in_border = bw > 0.0 ? smoothstep(-bw - 0.75, -bw + 0.75, d) : 0.0;
	float g = bw > 0.0 ? exp(-max(-d - bw, 0.0) / max(bw * 2.5, 1.0)) * glow * (1.0 - in_border) : 0.0;
	float sh = exp(-max(-d - bw, 0.0) / max(min(sz.x, sz.y) * 0.08, 1.0)) * shade * (1.0 - in_border);
	vec3 rgb = c.rgb * (1.0 - sh);
	rgb = rgb + bc * g * c.a;
	float al = c.a;
	rgb = mix(rgb, bc * max(al, colour_a.a), in_border * colour_a.a);
	al = mix(al, max(al, colour_a.a), in_border);
	COLOR = vec4(min(rgb, vec3(al)) * mask, al * mask);
}
