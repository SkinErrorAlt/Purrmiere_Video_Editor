shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D y_tex : filter_linear, repeat_disable;
uniform sampler2D uv_tex : filter_linear, repeat_disable;
uniform int colorspace = 1;
uniform bool full_range = false;
uniform bool has_frame = false;
uniform bool rgb_frame = false;
uniform vec4 missing_colour : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform int turn = 0;

vec2 turned(vec2 p) {
	if (turn == 90) {
		return vec2(p.y, 1.0 - p.x);
	}
	if (turn == 180) {
		return vec2(1.0 - p.x, 1.0 - p.y);
	}
	if (turn == 270) {
		return vec2(1.0 - p.y, p.x);
	}
	return p;
}

void fragment() {
	vec2 at = turned(UV);
	if (!has_frame) {
		COLOR = missing_colour;
	} else if (rgb_frame) {
		COLOR = vec4(texture(y_tex, at).rgb, 1.0);
	} else {
		float y = texture(y_tex, at).r;
		vec2 c = texture(uv_tex, at).rg;
		float yy;
		vec2 cc;
		if (full_range) {
			yy = y;
			cc = c - vec2(0.5);
		} else {
			yy = (y * 255.0 - 16.0) / 219.0;
			cc = (c * 255.0 - 128.0) / 224.0;
		}
		float cb = cc.x;
		float cr = cc.y;
		vec3 rgb;
		if (colorspace == 0) {
			rgb = vec3(yy + 1.402 * cr, yy - 0.344136 * cb - 0.714136 * cr, yy + 1.772 * cb);
		} else if (colorspace == 2) {
			rgb = vec3(yy + 1.4746 * cr, yy - 0.16455 * cb - 0.57135 * cr, yy + 1.8814 * cb);
		} else {
			rgb = vec3(yy + 1.5748 * cr, yy - 0.187324 * cb - 0.468124 * cr, yy + 1.8556 * cb);
		}
		COLOR = vec4(clamp(rgb, 0.0, 1.0), 1.0);
	}
}
