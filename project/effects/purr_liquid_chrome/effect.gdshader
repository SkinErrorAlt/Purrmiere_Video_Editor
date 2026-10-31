shader_type canvas_item;
render_mode blend_disabled;

uniform float relief : hint_range(0.0, 20.0) = 4.0;
uniform float soft : hint_range(0.0, 12.0) = 2.5;
uniform vec4 sky : source_color = vec4(0.78, 0.88, 1.0, 1.0);
uniform vec4 ground : source_color = vec4(0.22, 0.16, 0.12, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float detail : hint_range(0.0, 1.0) = 0.35;
uniform float flow : hint_range(0.0, 2.0) = 0.2;
uniform float shine : hint_range(0.0, 2.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

float ht(sampler2D tx, vec2 uv) {
	vec2 t = TX(max(soft, 0.3));
	float s = lum(unp(texture(tx, uv))) * 2.0;
	s += lum(unp(texture(tx, uv + vec2(t.x, 0.0)))) + lum(unp(texture(tx, uv - vec2(t.x, 0.0))));
	s += lum(unp(texture(tx, uv + vec2(0.0, t.y)))) + lum(unp(texture(tx, uv - vec2(0.0, t.y))));
	return s / 6.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 e = TX(max(soft, 0.5));
	float h0 = ht(TEXTURE, UV);
	float hx = ht(TEXTURE, UV + vec2(e.x, 0.0)) - ht(TEXTURE, UV - vec2(e.x, 0.0));
	float hy = ht(TEXTURE, UV + vec2(0.0, e.y)) - ht(TEXTURE, UV - vec2(0.0, e.y));
	vec3 n = normalize(vec3(-hx * relief, -hy * relief, 1.0));
	vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
	float y = r.y + (UV.y - 0.5) * 1.2 + 0.12 * sin(r.x * 4.0 + UV.x * 3.0 + clip_time * flow * 2.0);
	vec3 env = mix(mix(vec3(1.0), sky.rgb * 0.75, clamp(-y * 2.5, 0.0, 1.0)), ground.rgb * (0.6 + clamp(y * 2.0, 0.0, 1.0) * 0.8), smoothstep(-0.03, 0.03, y));
	env += vec3(1.0) * exp(-abs(y) * 40.0) * 0.8;
	env += vec3(0.25) * sin(r.x * 9.0 + clip_time * flow) * smoothstep(0.0, 0.4, -y) * 0.3;
	float spec = pow(clamp(dot(n, normalize(vec3(-0.4, -0.5, 1.0))), 0.0, 1.0), 60.0) * shine;
	vec3 o = env * tint.rgb * mix(vec3(1.0), vec3(0.4 + h0 * 1.1), detail) + vec3(spec);
	COLOR = pm(o, c.a);
}
