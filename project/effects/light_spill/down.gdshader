shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

vec4 dec(vec4 c) {
	return vec4(c.rgb * c.rgb * c.rgb * 4.0, c.a * c.a);
}

vec4 enc(vec4 v) {
	return vec4(pow(clamp(v.rgb * 0.25, 0.0, 1.0), vec3(1.0 / 3.0)), sqrt(clamp(v.a, 0.0, 1.0)));
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 sum = (dec(texture(TEXTURE, UV + px * vec2(-1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, -1.0))) + dec(texture(TEXTURE, UV + px * vec2(-1.0, 1.0))) + dec(texture(TEXTURE, UV + px * vec2(1.0, 1.0)))) * 0.125;
	sum += dec(texture(TEXTURE, UV)) * 0.125;
	sum += (dec(texture(TEXTURE, UV + px * vec2(-2.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(2.0, 0.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, -2.0))) + dec(texture(TEXTURE, UV + px * vec2(0.0, 2.0)))) * 0.0625;
	sum += (dec(texture(TEXTURE, UV + px * vec2(-2.0, -2.0))) + dec(texture(TEXTURE, UV + px * vec2(2.0, -2.0))) + dec(texture(TEXTURE, UV + px * vec2(-2.0, 2.0))) + dec(texture(TEXTURE, UV + px * vec2(2.0, 2.0)))) * 0.03125;
	COLOR = enc(sum);
}
