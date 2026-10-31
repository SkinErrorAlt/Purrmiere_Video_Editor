shader_type canvas_item;
render_mode blend_disabled;

uniform int mode : hint_range(0, 1) = 1;
uniform float amount : hint_range(0.0, 1.0) = 0.85;
uniform float glow : hint_range(0.0, 1.0) = 0.3;
uniform float glow_size : hint_range(1.0, 60.0) = 12.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.15;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float ir_of(vec3 c) {
	float base = max(dot(c, vec3(0.45, 0.45, 0.1)), min(c.r * 1.1, 1.0));
	float foliage = clamp((c.g - max(c.r * 0.85, c.b)) / max(c.g, 0.04) * 2.5, 0.0, 1.0) * smoothstep(0.02, 0.15, c.g);
	float sky = clamp((c.b - max(c.r, c.g)) / max(c.b, 0.05) * 2.0, 0.0, 1.0);
	float target = 0.55 + 0.45 * smoothstep(0.0, 0.5, c.g);
	float ir = mix(base, target, foliage * amount);
	return ir * (1.0 - sky * 0.8 * amount);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float ir = ir_of(rgb);
	vec3 outc = mode == 1 ? vec3(ir, rgb.r, rgb.g) : vec3(ir);
	outc = (outc - 0.5) * contrast + 0.5;
	if (glow > 0.0) {
		float radius = glow_size * px_scale;
		float acc = 0.0;
		for (int i = 0; i < 12; i++) {
			float fi = float(i);
			float ang = fi * 2.3999632;
			float r = sqrt((fi + 0.5) / 12.0) * radius;
			vec2 off = vec2(cos(ang), sin(ang)) * r / dims;
			vec4 s = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
			vec3 sc = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			acc += smoothstep(0.55, 1.0, ir_of(sc)) * s.a;
		}
		vec3 tint = mode == 1 ? vec3(1.0, 0.6, 0.65) : vec3(1.0);
		vec3 halo = clamp(tint * acc / 12.0 * glow * 1.5, 0.0, 1.0);
		outc = 1.0 - (1.0 - clamp(outc, 0.0, 1.0)) * (1.0 - halo);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
