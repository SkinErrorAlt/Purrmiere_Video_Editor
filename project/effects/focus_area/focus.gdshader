shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.02, 1.5) = 0.3;
uniform float stretch : hint_range(0.25, 4.0) = 1.3;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform float feather : hint_range(0.0, 1.0) = 0.35;
uniform float blur : hint_range(0.0, 1.0) = 0.75;
uniform float darken : hint_range(0.0, 1.0) = 0.45;
uniform float desaturate : hint_range(0.0, 1.0) = 0.6;
uniform float ring_width : hint_range(0.0, 30.0) = 0.0;
uniform vec4 ring_colour : source_color = vec4(1.0, 0.85, 0.2, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 far_blur(sampler2D tex, vec2 uv) {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 s = texture(tex, uv) * 4.0;
	s += texture(tex, uv + px * vec2(-1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(1.0, 0.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, -1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(0.0, 1.0)) * 2.0;
	s += texture(tex, uv + px * vec2(-1.0, -1.0));
	s += texture(tex, uv + px * vec2(1.0, -1.0));
	s += texture(tex, uv + px * vec2(-1.0, 1.0));
	s += texture(tex, uv + px * vec2(1.0, 1.0));
	return s / 16.0;
}

void fragment() {
	vec4 sharp = texture(effect_tex, UV);
	vec2 full = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * full.x / max(tex_size.x, 1.0), 0.0001);
	vec2 d = (UV - centre) * full;
	float ang = radians(rotation);
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 l = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
	float r = max(size, 0.001) * full.y * 0.5;
	vec2 axes = vec2(r * max(stretch, 0.05), r);
	float e = length(l / axes);
	float fw = max(clamp(feather, 0.0, 1.0) * 0.9, 0.004);
	float outside = smoothstep(1.0, 1.0 + fw, e);
	float b = clamp(blur, 0.0, 1.0);
	vec4 mid = texture(mid_tex, UV);
	vec4 soft = b < 0.5 ? mix(sharp, mid, b * 2.0) : mix(mid, far_blur(TEXTURE, UV), (b - 0.5) * 2.0);
	vec4 o = mix(sharp, soft, outside);
	vec3 rgb = o.a > 0.0001 ? o.rgb / o.a : vec3(0.0);
	float l_y = dot(rgb, LUMA);
	rgb = mix(rgb, vec3(l_y), clamp(desaturate, 0.0, 1.0) * outside);
	rgb *= 1.0 - clamp(darken, 0.0, 1.0) * 0.85 * outside;
	float rw = max(ring_width, 0.0) * ps;
	float oa = o.a;
	if (rw > 0.0) {
		float local_r = length(axes * normalize(l / axes + vec2(0.00001)));
		float dist = abs(e - 1.0) * local_r;
		float ring = 1.0 - smoothstep(rw * 0.5 - 0.75, rw * 0.5 + 0.75, dist);
		rgb = mix(rgb, ring_colour.rgb, ring * ring_colour.a);
		oa = max(oa, ring * ring_colour.a);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
