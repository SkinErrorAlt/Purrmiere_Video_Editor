shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 base = vec2(0.5, 0.92);
uniform float angle : hint_range(-180.0, 180.0) = -35.0;
uniform float length_scale : hint_range(0.0, 3.0) = 0.6;
uniform float opacity : hint_range(0.0, 1.0) = 0.6;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness_near : hint_range(0.0, 50.0) = 2.0;
uniform float softness_far : hint_range(0.0, 150.0) = 30.0;
uniform float fade : hint_range(0.0, 1.0) = 0.7;
uniform float contact : hint_range(0.0, 1.0) = 0.5;
uniform bool shadow_only = false;

float alpha_at(sampler2D tex, vec2 p_px, vec2 size) {
	vec2 uv = p_px / size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float k = max(px_scale, 0.0001);
	vec2 p = UV * size;
	vec2 b = base * size;
	float ang = radians(angle);
	vec2 dir = vec2(sin(ang), -cos(ang));
	if (abs(dir.y) < 0.12) {
		dir.y = dir.y < 0.0 ? -0.12 : 0.12;
	}
	float len = max(length_scale, 0.0);
	float shadow = 0.0;
	if (len > 0.001) {
		float h = (p.y - b.y) / (len * dir.y);
		if (h >= 0.0 && h <= b.y) {
			float sx = p.x - h * len * dir.x;
			vec2 s = vec2(sx, b.y - h);
			float along = clamp(h / max(b.y, 1.0), 0.0, 1.0);
			float r = mix(softness_near, softness_far, along) * k;
			float sum = alpha_at(TEXTURE, s, size) * 2.0;
			float n = 2.0;
			if (r > 0.5) {
				float spin = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) * 6.28318530718;
				for (int i = 0; i < 32; i++) {
					float fi = float(i) + 0.5;
					float rr = sqrt(fi / 32.0) * r;
					float ga = fi * 2.39996323 + spin;
					sum += alpha_at(TEXTURE, s + vec2(cos(ga), sin(ga)) * rr, size);
					n += 1.0;
				}
			}
			float sa = sum / n;
			float op = opacity * (1.0 - fade * along);
			float near = 1.0 - smoothstep(0.0, 0.06 * max(b.y, 1.0), h);
			op = min(op + contact * opacity * near, 1.0);
			shadow = clamp(sa * op * colour.a, 0.0, 1.0);
		}
	}
	vec4 sh = vec4(colour.rgb * shadow, shadow);
	vec4 pic = texture(TEXTURE, UV);
	if (shadow_only) {
		COLOR = sh;
	} else {
		COLOR = pic + sh * (1.0 - pic.a);
	}
}
