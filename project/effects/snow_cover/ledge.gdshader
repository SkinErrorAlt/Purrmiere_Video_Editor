shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
#define LUMT(uv) dot(texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))).rgb, LUMA)

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	float d = 2.0;
	float up = 0.0;
	float dn = 0.0;
	float lf = 0.0;
	float rt = 0.0;
	for (int i = -2; i <= 2; i++) {
		float fi = float(i) * d * 0.75;
		up += LUMT(UV + vec2(fi, -d) * px);
		dn += LUMT(UV + vec2(fi, d) * px);
		lf += LUMT(UV + vec2(-d, fi) * px);
		rt += LUMT(UV + vec2(d, fi) * px);
	}
	float gy = (dn - up) / 5.0;
	float gx = (rt - lf) / 5.0;
	float ledge = clamp((abs(gy) - 0.9 * abs(gx) - 0.04) * 6.0, 0.0, 1.0);
	COLOR = vec4(ledge, LUMT(UV), 0.0, 1.0);
}
