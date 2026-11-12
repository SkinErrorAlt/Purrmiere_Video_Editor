shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform sampler2D level_tex : filter_linear, repeat_disable;
uniform float reach : hint_range(0.0, 1.0) = 0.7;

vec4 dec(vec4 c) {
	return vec4(c.rgb * c.rgb * c.rgb * 4.0, c.a * c.a);
}

vec4 enc(vec4 v) {
	return vec4(pow(clamp(v.rgb * 0.25, 0.0, 1.0), vec3(1.0 / 3.0)), sqrt(clamp(v.a, 0.0, 1.0)));
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 sum = dec(texture(TEXTURE, UV)) * 4.0;
	sum += (dec(texture(TEXTURE, UV + px * vec2(-1.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, 1.0)))) * 2.0;
	sum += dec(texture(TEXTURE, UV + px * vec2(-1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(-1.0, 1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, 1.0)));
	vec4 up = sum / 16.0;
	vec4 lev = dec(texture(level_tex, UV));
	float boost = mix(1.2, 2.6, clamp(reach, 0.0, 1.0));
	vec3 light = (lev.rgb + up.rgb * boost) / (1.0 + boost * 0.5);
	float ambient = mix(lev.a, up.a, 0.6);
	COLOR = enc(vec4(light, ambient));
}
