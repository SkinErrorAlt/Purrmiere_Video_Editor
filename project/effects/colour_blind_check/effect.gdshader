shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int kind : hint_range(0, 3) = 1;
uniform float severity : hint_range(0.0, 1.0) = 1.0;
uniform bool half_and_half = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	vec3 x = clamp(c, 0.0, 1.0);
	return mix(x * 12.92, 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), x));
}

vec3 simulate(vec3 lin) {
	if (kind == 0) {
		return vec3(dot(lin, vec3(0.152286, 1.052583, -0.204868)), dot(lin, vec3(0.114503, 0.786281, 0.099216)), dot(lin, vec3(-0.003882, -0.048116, 1.051998)));
	}
	if (kind == 1) {
		return vec3(dot(lin, vec3(0.367322, 0.860646, -0.227968)), dot(lin, vec3(0.280085, 0.672501, 0.047413)), dot(lin, vec3(-0.011820, 0.042940, 0.968881)));
	}
	if (kind == 2) {
		return vec3(dot(lin, vec3(1.255528, -0.076749, -0.178779)), dot(lin, vec3(-0.078411, 0.930809, 0.147602)), dot(lin, vec3(0.004733, 0.691367, 0.303900)));
	}
	return vec3(dot(lin, LUMA));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 lin = to_linear(rgb);
	vec3 sim = mix(lin, simulate(lin), clamp(severity, 0.0, 1.0));
	vec3 c = to_display(max(sim, vec3(0.0)));
	if (half_and_half) {
		float x = UV.x * max(tex_size.x, 1.0);
		float mid = 0.5 * max(tex_size.x, 1.0);
		if (x < mid) {
			c = rgb;
		}
		float line = clamp(max(px_scale, 1.0) - abs(x - mid) + 0.5, 0.0, 1.0);
		c = mix(c, vec3(1.0), line);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0) * a, a);
}
