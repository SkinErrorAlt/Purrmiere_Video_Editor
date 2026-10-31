shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

const float HEAD = 16.0;

vec4 dec(sampler2D tex, vec2 uv) {
	vec4 e = texture(tex, uv);
	return e * e * HEAD;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 a = dec(TEXTURE, UV + px * vec2(-2.0, -2.0));
	vec4 b = dec(TEXTURE, UV + px * vec2(0.0, -2.0));
	vec4 c = dec(TEXTURE, UV + px * vec2(2.0, -2.0));
	vec4 d = dec(TEXTURE, UV + px * vec2(-2.0, 0.0));
	vec4 e = dec(TEXTURE, UV);
	vec4 f = dec(TEXTURE, UV + px * vec2(2.0, 0.0));
	vec4 g = dec(TEXTURE, UV + px * vec2(-2.0, 2.0));
	vec4 h = dec(TEXTURE, UV + px * vec2(0.0, 2.0));
	vec4 i = dec(TEXTURE, UV + px * vec2(2.0, 2.0));
	vec4 j = dec(TEXTURE, UV + px * vec2(-1.0, -1.0));
	vec4 k = dec(TEXTURE, UV + px * vec2(1.0, -1.0));
	vec4 l = dec(TEXTURE, UV + px * vec2(-1.0, 1.0));
	vec4 m = dec(TEXTURE, UV + px * vec2(1.0, 1.0));
	vec4 sum = (j + k + l + m) * 0.5;
	sum += (a + b + d + e) * 0.125;
	sum += (b + c + e + f) * 0.125;
	sum += (d + e + g + h) * 0.125;
	sum += (e + f + h + i) * 0.125;
	vec4 v = sum * 0.25;
	vec4 enc = sqrt(clamp(v / HEAD, 0.0, 1.0));
	COLOR = clamp(enc + (hash12(FRAGCOORD.xy) - 0.5) / 255.0, 0.0, 1.0);
}
