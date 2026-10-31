shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int style = 0;
uniform float depth : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = 90.0;
uniform float shrink : hint_range(0.0, 0.5) = 0.12;

float lift(vec2 pc) {
	vec2 c = clamp(pc, 0.0, 1.0);
	float cx = abs(c.x * 2.0 - 1.0);
	float cy = abs(c.y * 2.0 - 1.0);
	if (style == 1) {
		return 1.0 - cx * cx;
	}
	float k = cx * cy;
	return k * k;
}

float fetch(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).r;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.x / size.y;
	float sc = max(1.0 - shrink, 0.05);
	vec2 pc = (UV - 0.5) / sc + 0.5;
	float h = lift(pc);
	float an = radians(light_angle);
	vec2 away = -vec2(cos(an), -sin(an));
	float dep = clamp(depth, 0.0, 1.0);
	float soft = clamp(softness, 0.0, 1.0);
	float reach = 0.003 + dep * 0.06 * h;
	vec2 centre = UV - away * reach / vec2(aspect, 1.0);
	float r = 0.002 + soft * (0.004 + 0.06 * dep * h);
	float rt = r * size.y;
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = 0; i < 32; i++) {
		float fi = float(i);
		float rr = sqrt((fi + 0.5) / 32.0);
		float th = fi * 2.39996323;
		vec2 o = vec2(cos(th), sin(th)) * rr * r / vec2(aspect, 1.0);
		float w = exp(-rr * rr * 2.0);
		sum += fetch(TEXTURE, centre + o) * w;
		wsum += w;
	}
	float s = sum / wsum;
	if (rt < 0.75) {
		s = fetch(TEXTURE, centre);
	}
	float weight = style == 0 ? mix(0.7, 1.0, h) : mix(0.8, 1.0, h);
	COLOR = vec4(vec3(clamp(s * weight, 0.0, 1.0)), 1.0);
}
