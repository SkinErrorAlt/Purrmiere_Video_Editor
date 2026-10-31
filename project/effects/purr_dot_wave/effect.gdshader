shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(4.0, 80.0) = 14.0;
uniform float wave : hint_range(0.0, 40.0) = 6.0;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float length_scale : hint_range(0.1, 4.0) = 1.0;
uniform int colour_mode : hint_range(0, 1) = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.6, 0.8, 1.0);
uniform vec4 bg : source_color = vec4(0.04, 0.03, 0.06, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

void fragment() {
	vec2 P = PX(UV);
	vec2 k = px_scale / max(tex_size, vec2(1.0));
	vec3 o = bg.rgb;
	float cx = floor(P.x / cell);
	for (int j = -1; j <= 1; j++) {
		float cy = floor(P.y / cell) + float(j);
		vec2 cen = (vec2(cx, cy) + 0.5) * cell;
		float off = sin(cen.x / cell * 0.5 / length_scale + cen.y / cell * 0.2 - clip_time * speed * 3.0) * wave;
		vec4 sc = texture(TEXTURE, clamp(cen * k, vec2(0.0), vec2(1.0)));
		float l = lum(unp(sc)) * sc.a;
		float r = sqrt(l) * cell * 0.5;
		float d = length(P - cen - vec2(0.0, off));
		float dk = smoothstep(r + 0.7, r - 0.7, d);
		vec3 dc = colour_mode == 0 ? unp(sc) : colour.rgb;
		o = mix(o, dc, dk);
	}
	COLOR = pm(o, 1.0);
}
