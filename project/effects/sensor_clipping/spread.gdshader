shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float bloom_length : hint_range(2.0, 300.0) = 40.0;
uniform float fringe_width : hint_range(1.0, 30.0) = 6.0;

float over_at(sampler2D t, vec2 uv) {
	float e = min(texture(t, uv).r, 0.999);
	return -log(1.0 - e) * 2.0;
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	float col = 0.0;
	for (int i = 0; i < 64; i++) {
		col += over_at(TEXTURE, vec2(UV.x, (float(i) + 0.5) / 64.0));
	}
	col /= 64.0;
	float len = max(bloom_length * px_scale, 0.75);
	float step_y = max(len / 10.0, 0.5);
	float bloom = 0.0;
	for (int i = -30; i <= 30; i++) {
		float d = float(i) * step_y;
		float w = exp(-abs(d) / len) * step_y / len;
		bloom += over_at(TEXTURE, UV + vec2(0.0, d * px.y)) * w;
	}
	float side = max(len * 0.08, 0.5);
	bloom += 0.15 * (over_at(TEXTURE, UV + vec2(side * px.x, 0.0)) + over_at(TEXTURE, UV - vec2(side * px.x, 0.0)));
	float fr = max(fringe_width * px_scale, 0.5);
	float spread = 0.0;
	for (int i = 0; i < 20; i++) {
		float rr = sqrt((float(i) + 0.5) / 20.0) * fr;
		float th = float(i) * 2.39996323;
		spread += texture(TEXTURE, UV + vec2(cos(th), sin(th)) * rr * px).g;
	}
	spread /= 20.0;
	COLOR = vec4(1.0 - exp(-col * 4.0), 1.0 - exp(-bloom), spread, 1.0);
}
