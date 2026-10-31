shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 position = vec2(0.5, 0.5);
uniform float size : hint_range(0.005, 0.5) = 0.04;
uniform float thickness : hint_range(0.5, 30.0) = 4.0;
uniform float gap : hint_range(0.0, 0.9) = 0.4;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool final_hit = false;
uniform vec4 final_colour : source_color = vec4(1.0, 0.15, 0.12, 1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.5;
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.05, 5.0) = 0.3;
uniform float repeat_every : hint_range(0.0, 10.0) = 0.0;
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dt = clip_time - starts_at;
	if (repeat_every > 0.001 && dt >= 0.0) {
		dt = mod(dt, repeat_every);
	}
	if (dt < 0.0 || dt > duration) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float f = dt / max(duration, 0.001);
		float pop = 1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.25, f));
		float fade = 1.0 - smoothstep(0.55, 1.0, f);
		float unit = max(size * pop, 0.0001);
		vec2 p = (UV - position) * vec2(sz.x / sz.y, 1.0) / unit;
		vec2 q = abs(p);
		vec2 n = vec2(0.70710678);
		float along = clamp(dot(q, n), gap * 0.70710678, 0.70710678);
		float d = length(q - n * along);
		float th = thickness * px_scale * 0.5 / (sz.y * unit);
		float aa = 1.0 / (sz.y * unit);
		float core = 1.0 - smoothstep(th - aa, th + aa, d);
		float edge = (1.0 - smoothstep(th * 1.9 - aa, th * 1.9 + aa, d)) * outline;
		vec4 col = final_hit ? final_colour : colour;
		float ae = edge * fade;
		vec3 rgb = c.rgb * (1.0 - ae);
		float al = c.a + ae * (1.0 - c.a);
		float ac = core * fade * col.a;
		rgb = rgb * (1.0 - ac) + col.rgb * ac;
		al = al + ac * (1.0 - al);
		COLOR = vec4(rgb, al);
	}
}
