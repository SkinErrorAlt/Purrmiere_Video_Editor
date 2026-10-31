shader_type canvas_item;
render_mode blend_disabled;

uniform float dot_size : hint_range(2.0, 64.0) = 8.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform float sharpness : hint_range(0.0, 1.0) = 0.6;
uniform bool colour_dots = false;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float step_px = max(dot_size * max(px_scale, 0.0001), 1.0);
	float rad = radians(angle);
	vec2 px = UV * tex_size;
	mat2 rot = mat2(vec2(cos(rad), -sin(rad)), vec2(sin(rad), cos(rad)));
	vec2 grid = rot * px / step_px;
	vec2 cell = fract(grid) - 0.5;
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float radius = sqrt(max(1.0 - luma, 0.0)) * 0.72;
	float d = length(cell);
	float soft = mix(0.35, 0.01, sharpness);
	float cover = 1.0 - smoothstep(radius - soft, radius + soft, d);
	rgb = mix(paper.rgb, colour_dots ? rgb : ink.rgb, cover);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
