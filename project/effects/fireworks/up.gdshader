shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform sampler2D level_tex : filter_linear, repeat_disable;
uniform float keep = 0.5;

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec3 sum = texture(TEXTURE, UV).rgb * 4.0;
	sum += texture(TEXTURE, UV + px * vec2(-1.0, 0.0)).rgb * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(1.0, 0.0)).rgb * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(0.0, -1.0)).rgb * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(0.0, 1.0)).rgb * 2.0;
	sum += texture(TEXTURE, UV + px * vec2(-1.0, -1.0)).rgb;
	sum += texture(TEXTURE, UV + px * vec2(1.0, -1.0)).rgb;
	sum += texture(TEXTURE, UV + px * vec2(-1.0, 1.0)).rgb;
	sum += texture(TEXTURE, UV + px * vec2(1.0, 1.0)).rgb;
	vec3 lower = sum / 16.0;
	COLOR = vec4(clamp(lower + texture(level_tex, UV).rgb * keep, 0.0, 1.0), 1.0);
}
