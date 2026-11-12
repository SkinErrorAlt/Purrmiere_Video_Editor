uniform sampler2DArray history_tex : filter_linear, repeat_disable;
uniform int history_layer[64];
uniform int history_count = 0;
uniform float history_fps = 30.0;

bool history_has(int age) {
	if (age <= 0 || age > history_count) {
		return false;
	}
	return history_layer[age - 1] >= 0;
}

vec4 history_frame(int age, vec2 uv, vec4 now) {
	if (age <= 0 || age > history_count) {
		return now;
	}
	int layer = history_layer[age - 1];
	if (layer < 0) {
		return now;
	}
	return texture(history_tex, vec3(uv, float(layer)));
}

vec4 history_between(float age, vec2 uv, vec4 now) {
	float a = clamp(age, 0.0, float(history_count));
	int lo = int(floor(a));
	float f = a - float(lo);
	vec4 x = lo <= 0 ? now : history_frame(lo, uv, now);
	if (f < 0.002) {
		return x;
	}
	vec4 y = history_frame(lo + 1, uv, x);
	return mix(x, y, f);
}
