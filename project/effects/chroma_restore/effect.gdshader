shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int source : hint_range(0, 3) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float shift_x : hint_range(-8.0, 8.0) = 0.0;
uniform float shift_y : hint_range(-8.0, 8.0) = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

vec2 chroma_of(vec3 c) {
	float y = dot(c, LUMA);
	return vec2((c.b - y) / 1.8556, (c.r - y) / 1.5748);
}

void fragment() {
	vec2 px = max(px_scale, 0.0001) / max(tex_size, vec2(1.0));
	vec2 shift = vec2(shift_x, shift_y) * px;
	vec2 rad = vec2(3.0, 1.5);
	vec2 soft = vec2(1.0, 1.0);
	float sigma = 2.0;
	if (source == 1) {
		rad = vec2(3.0, 1.0);
		soft = vec2(1.0, 0.0);
	} else if (source == 2) {
		rad = vec2(6.0, 1.0);
		soft = vec2(2.0, 0.0);
		sigma = 3.5;
	} else if (source == 3) {
		rad = vec2(8.0, 1.0);
		soft = vec2(2.5, 0.0);
		sigma = 4.5;
	}
	vec2 stp = vec2(rad.x / 4.0, rad.y / 2.0);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = straight(c);
	float y0 = dot(rgb, LUMA);
	float sy = 0.0;
	float syy = 0.0;
	vec2 sc = vec2(0.0);
	vec2 syc = vec2(0.0);
	float n = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -4; i <= 4; i++) {
			vec2 o = vec2(float(i), float(j)) * stp;
			float w = exp(-dot(o, o) / (2.0 * sigma * sigma));
			vec2 uv = UV + o * px;
			float y1 = dot(straight(texture(TEXTURE, clamp(uv + vec2(soft.x, soft.y) * px, vec2(0.0), vec2(1.0)))), LUMA);
			float y2 = dot(straight(texture(TEXTURE, clamp(uv + vec2(-soft.x, soft.y) * px, vec2(0.0), vec2(1.0)))), LUMA);
			float y3 = dot(straight(texture(TEXTURE, clamp(uv + vec2(soft.x, -soft.y) * px, vec2(0.0), vec2(1.0)))), LUMA);
			float y4 = dot(straight(texture(TEXTURE, clamp(uv + vec2(-soft.x, -soft.y) * px, vec2(0.0), vec2(1.0)))), LUMA);
			float yy = 0.25 * (y1 + y2 + y3 + y4);
			vec2 cc = chroma_of(straight(texture(TEXTURE, clamp(uv - shift, vec2(0.0), vec2(1.0)))));
			sy += w * yy;
			syy += w * yy * yy;
			sc += w * cc;
			syc += w * yy * cc;
			n += w;
		}
	}
	float my = sy / n;
	float vy = max(syy / n - my * my, 0.0);
	vec2 mc = sc / n;
	vec2 cov = syc / n - my * mc;
	vec2 slope = cov / (vy + 0.0001);
	vec2 inter = mc - slope * my;
	vec2 rebuilt = slope * y0 + inter;
	vec2 shifted_own = chroma_of(straight(texture(TEXTURE, clamp(UV - shift, vec2(0.0), vec2(1.0)))));
	vec2 chroma = mix(shifted_own, rebuilt, clamp(strength, 0.0, 1.0));
	float r = y0 + 1.5748 * chroma.y;
	float b = y0 + 1.8556 * chroma.x;
	float g = (y0 - 0.2126 * r - 0.0722 * b) / 0.7152;
	vec3 outc = clamp(vec3(r, g, b), 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
