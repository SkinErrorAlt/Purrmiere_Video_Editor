shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float luma_strength : hint_range(0.0, 1.0) = 0.5;
uniform float chroma_strength : hint_range(0.0, 1.0) = 0.6;
uniform float detail : hint_range(0.0, 1.0) = 0.2;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_ycc(vec3 c) {
	float y = dot(c, LUMA);
	return vec3(y, (c.b - y) / 1.8556, (c.r - y) / 1.5748);
}

vec3 from_ycc(vec3 ycc) {
	float r = ycc.x + 1.5748 * ycc.z;
	float b = ycc.x + 1.8556 * ycc.y;
	float g = (ycc.x - 0.2126 * r - 0.0722 * b) / 0.7152;
	return vec3(r, g, b);
}

void fragment() {
	vec2 inv = 1.0 / max(tex_size, vec2(1.0));
	float sp = max(px_scale, 0.25);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 ycc0 = to_ycc(rgb);
	float ls = clamp(luma_strength, 0.0, 1.0);
	float cs = clamp(chroma_strength, 0.0, 1.0);
	float sr = 0.02 + 0.16 * ls;
	float inv_sr = 1.0 / (2.0 * sr * sr);
	float ysum = 0.0;
	float ywt = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 o = vec2(float(i), float(j));
			vec4 t = texture(TEXTURE, clamp(UV + o * sp * inv, vec2(0.0), vec2(1.0)));
			float ty = t.a > 0.0001 ? dot(t.rgb / t.a, LUMA) : 0.0;
			float dy = ty - ycc0.x;
			float w = exp(-dot(o, o) / 4.5 - dy * dy * inv_sr) * t.a;
			ysum += ty * w;
			ywt += w;
		}
	}
	float yf = ywt > 0.0001 ? ysum / ywt : ycc0.x;
	float cstep = (1.0 + 3.0 * cs) * sp;
	vec2 csum = vec2(0.0);
	float cwt = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 o = vec2(float(i), float(j));
			vec4 t = texture(TEXTURE, clamp(UV + o * cstep * inv, vec2(0.0), vec2(1.0)));
			vec3 trgb = t.a > 0.0001 ? t.rgb / t.a : vec3(0.0);
			vec3 tycc = to_ycc(trgb);
			float dy = tycc.x - ycc0.x;
			float w = exp(-dot(o, o) / 4.5 - dy * dy * 12.0) * t.a;
			csum += tycc.yz * w;
			cwt += w;
		}
	}
	vec2 cf = cwt > 0.0001 ? csum / cwt : ycc0.yz;
	float y_out = mix(ycc0.x, yf, min(ls * 1.5, 1.0));
	y_out = mix(y_out, ycc0.x, clamp(detail, 0.0, 1.0));
	vec2 c_out = mix(ycc0.yz, cf, min(cs * 1.5, 1.0));
	vec3 outc = from_ycc(vec3(y_out, c_out));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
