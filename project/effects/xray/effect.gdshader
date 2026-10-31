shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 tint : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float edge_boost : hint_range(0.0, 3.0) = 1.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.3;
uniform float glow : hint_range(0.0, 1.0) = 0.35;
uniform float glow_size : hint_range(1.0, 60.0) = 10.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

#define INV(p) inv_luma(texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0))))

float inv_luma(vec4 s) {
	vec3 c = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	return (1.0 - dot(c, vec3(0.2126, 0.7152, 0.0722))) * s.a;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	float v = a > 0.0001 ? inv_luma(c) / a : 0.0;
	vec2 e = vec2(max(1.5 * px_scale, 1.0)) / dims;
	float tl = INV(UV + vec2(-e.x, -e.y));
	float tc = INV(UV + vec2(0.0, -e.y));
	float tr = INV(UV + vec2(e.x, -e.y));
	float ml = INV(UV + vec2(-e.x, 0.0));
	float mr = INV(UV + vec2(e.x, 0.0));
	float bl = INV(UV + vec2(-e.x, e.y));
	float bc = INV(UV + vec2(0.0, e.y));
	float br = INV(UV + vec2(e.x, e.y));
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float edge = clamp(length(vec2(gx, gy)) * 0.25, 0.0, 1.0);
	v = (v - 0.5) * contrast + 0.5;
	v += edge_boost * edge * 0.8;
	v = clamp(v, 0.0, 1.5);
	if (glow > 0.0) {
		float radius = glow_size * px_scale;
		float acc = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.7853982 + 0.3926991;
			vec2 off = vec2(cos(ang), sin(ang)) * radius / dims;
			acc += smoothstep(0.4, 1.0, INV(UV + off));
			acc += smoothstep(0.4, 1.0, INV(UV + off * 0.45));
		}
		float g = acc / 16.0 * glow;
		v = 1.0 - (1.0 - clamp(v, 0.0, 1.0)) * (1.0 - g);
	}
	vec3 rgb = mix(tint.rgb * v, vec3(1.0), smoothstep(0.75, 1.3, v));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
