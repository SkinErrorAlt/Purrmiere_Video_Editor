shader_type canvas_item;
render_mode blend_disabled;

uniform float centre : hint_range(0.0, 1.0) = 0.5;
uniform float band : hint_range(0.0, 1.0) = 0.2;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform float strength : hint_range(0.0, 40.0) = 8.0;
uniform bool vertical_band = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	float along = vertical_band ? UV.x : UV.y;
	float d = abs(along - centre);
	float blur = smoothstep(band * 0.5, band * 0.5 + max(softness, 0.0001), d);
	float px = strength * max(px_scale, 0.0001) * blur;
	vec2 step_uv = vec2(px) / max(tex_size, vec2(1.0));
	vec4 sum = texture(TEXTURE, UV) * 4.0;
	sum += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)) * 2.0;
	sum += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)) * 2.0;
	sum += texture(TEXTURE, UV + vec2(0.0, step_uv.y)) * 2.0;
	sum += texture(TEXTURE, UV - vec2(0.0, step_uv.y)) * 2.0;
	sum += texture(TEXTURE, UV + step_uv);
	sum += texture(TEXTURE, UV - step_uv);
	sum += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y));
	sum += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y));
	COLOR = sum / 16.0;
}
