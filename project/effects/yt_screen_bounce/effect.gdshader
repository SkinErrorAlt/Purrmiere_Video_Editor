shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(0.05, 0.9) = 0.3;
uniform float speed_x : hint_range(0.0, 3.0) = 0.35;
uniform float speed_y : hint_range(0.0, 3.0) = 0.27;
uniform vec2 start = vec2(0.1, 0.2);
uniform bool tint_on_hit = true;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float clip_time;

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

float bounce(float s, float room, float speed, float t, out float hits) {
	float span = max(room, 0.0001);
	float u = s / span + t * speed / span;
	hits = floor(u);
	float f = fract(u);
	return (mod(hits, 2.0) < 1.0 ? f : 1.0 - f) * span;
}

void fragment() {
	float room = 1.0 - size;
	float hx;
	float hy;
	float x = bounce(clamp(start.x, 0.0, room), room, speed_x, clip_time, hx);
	float y = bounce(clamp(start.y, 0.0, room), room, speed_y, clip_time, hy);
	vec2 local = (UV - vec2(x, y)) / max(size, 0.0001);
	vec4 outc = vec4(background.rgb * background.a, background.a);
	if (local.x >= 0.0 && local.y >= 0.0 && local.x <= 1.0 && local.y <= 1.0) {
		vec4 c = texture(TEXTURE, local);
		if (tint_on_hit && c.a > 0.0001) {
			vec3 rgb = c.rgb / c.a;
			vec3 tc = hue(fract((hx + hy) * 0.17 + 0.05));
			rgb = mix(rgb, rgb * tc * 1.3, tint_amount);
			c = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
		}
		outc = vec4(c.rgb + outc.rgb * (1.0 - c.a), c.a + outc.a * (1.0 - c.a));
	}
	COLOR = outc;
}
