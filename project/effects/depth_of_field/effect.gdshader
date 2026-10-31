shader_type canvas_item;
render_mode blend_disabled;

uniform int depth_source : hint_range(0, 3) = 1;
uniform sampler2D picture : filter_linear, hint_default_black;
uniform float focus : hint_range(0.0, 1.0) = 0.5;
uniform float focus_range : hint_range(0.0, 1.0) = 0.15;
uniform float max_blur : hint_range(0.0, 60.0) = 14.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float bokeh_boost : hint_range(0.0, 3.0) = 0.6;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	float aspect = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	float d;
	float f = focus;
	if (depth_source == 0) {
		d = 1.0 - dot(texture(picture, UV).rgb, vec3(0.299, 0.587, 0.114));
	} else if (depth_source == 1) {
		d = 1.0 - UV.y;
	} else if (depth_source == 2) {
		d = UV.y;
	} else {
		d = length((UV - centre) * vec2(aspect, 1.0));
		f = 0.0;
	}
	float coc = clamp((abs(d - f) - focus_range * 0.5) / 0.35, 0.0, 1.0);
	float r = coc * max_blur * max(px_scale, 0.0001);
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 48; i++) {
		float fi = float(i);
		float th = fi * 2.39996323;
		vec4 s = texture(TEXTURE, UV + vec2(cos(th), sin(th)) * sqrt((fi + 0.5) / 48.0) * r * px);
		float w = 1.0 + bokeh_boost * smoothstep(0.6, 1.0, max(s.r, max(s.g, s.b))) * 4.0;
		sum += s * w;
		wsum += w;
	}
	COLOR = sum / wsum;
}
