shader_type canvas_item;
render_mode blend_disabled;

uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.05, 3.0) = 0.35;
uniform float repeat_every : hint_range(0.0, 10.0) = 0.0;
uniform float split : hint_range(0.0, 200.0) = 40.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float jolt : hint_range(0.0, 50.0) = 8.0;
uniform float wobble : hint_range(0.0, 1.0) = 0.4;
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec2 mirror(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0));
}

void fragment() {
	float dt = clip_time - starts_at;
	if (repeat_every > 0.001 && dt >= 0.0) {
		dt = mod(dt, repeat_every);
	}
	float env = 0.0;
	if (dt >= 0.0 && dt <= duration) {
		float f = dt / max(duration, 0.001);
		env = (1.0 - f) * (1.0 - f);
	}
	if (env <= 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float a = radians(angle) + wobble * sin(dt * 47.0) * 1.2;
		vec2 dir = vec2(cos(a), sin(a));
		vec2 off = dir * split * px_scale * env / max(tex_size, vec2(1.0));
		float s = 1.0 + jolt * 0.01 * env;
		vec2 uv = (UV - 0.5) / s + 0.5;
		vec4 r = texture(TEXTURE, mirror(uv + off));
		vec4 g = texture(TEXTURE, mirror(uv));
		vec4 b = texture(TEXTURE, mirror(uv - off));
		float al = max(max(r.a, g.a), b.a);
		COLOR = vec4(min(vec3(r.r, g.g, b.b), vec3(al)), al);
	}
}
