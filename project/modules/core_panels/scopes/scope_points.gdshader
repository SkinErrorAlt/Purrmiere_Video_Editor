shader_type canvas_item;
render_mode blend_add, unshaded;

// One instance per sampled pixel and channel. The vertex stage reads the frame and moves the point to where the
// scope plots it; additive blending turns many points into brightness.

uniform sampler2D frame : filter_nearest;
uniform vec2 grid = vec2(256.0, 144.0);
uniform vec2 out_size = vec2(512.0, 256.0);
uniform int mode = 0; // 0 luma waveform, 1 RGB waveform, 2 parade, 3 vectorscope, 4 histogram
uniform int channels = 1;
uniform float weight = 0.02;
uniform float vector_gain = 1.0;
uniform float hist_rows = 64.0;

varying vec4 tint;

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void vertex() {
	int id = INSTANCE_ID / channels;
	int ch = INSTANCE_ID - id * channels;
	int gx = int(grid.x);
	vec2 cell = vec2(float(id % gx), float(id / gx));
	vec2 uv = (cell + 0.5) / grid;
	vec3 rgb = straight(textureLod(frame, uv, 0.0));
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec2 at = vec2(0.0);
	vec3 col = vec3(1.0);
	float v = luma;
	if (mode == 1 || mode == 2 || mode == 4) {
		v = ch == 0 ? rgb.r : (ch == 1 ? rgb.g : rgb.b);
		col = ch == 0 ? vec3(1.0, 0.25, 0.2) : (ch == 1 ? vec3(0.3, 1.0, 0.35) : vec3(0.3, 0.5, 1.0));
	}
	if (mode == 0 || mode == 1) {
		at = vec2(uv.x * out_size.x, (1.0 - v) * (out_size.y - 1.0));
		col = mode == 0 ? vec3(0.55, 1.0, 0.6) : col;
	} else if (mode == 2) {
		float third = out_size.x / 3.0;
		at = vec2(float(ch) * third + uv.x * (third - 2.0) + 1.0, (1.0 - v) * (out_size.y - 1.0));
	} else if (mode == 3) {
		float cb = (rgb.b - luma) / 1.8556;
		float cr = (rgb.r - luma) / 1.5748;
		float r = min(out_size.x, out_size.y) * 0.5;
		at = out_size * 0.5 + vec2(cb, -cr) * 2.0 * r * vector_gain;
		col = mix(vec3(0.9), rgb, 0.65);
	} else {
		at = vec2(floor(v * (out_size.x - 1.0) + 0.5), mod(float(id), hist_rows));
		col = ch == 0 ? vec3(1.0, 0.0, 0.0) : (ch == 1 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0));
	}
	VERTEX = VERTEX + at + vec2(0.5);
	tint = vec4(col * weight, 1.0);
}

void fragment() {
	COLOR = tint;
}
