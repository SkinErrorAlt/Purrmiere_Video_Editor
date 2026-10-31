shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 m00 = vec2(0.0, 0.0);
uniform vec2 m10 = vec2(0.5, 0.0);
uniform vec2 m20 = vec2(1.0, 0.0);
uniform vec2 m01 = vec2(0.0, 0.5);
uniform vec2 m11 = vec2(0.5, 0.5);
uniform vec2 m21 = vec2(1.0, 0.5);
uniform vec2 m02 = vec2(0.0, 1.0);
uniform vec2 m12 = vec2(0.5, 1.0);
uniform vec2 m22 = vec2(1.0, 1.0);

vec3 lag(float t) {
	return vec3(2.0 * (t - 0.5) * (t - 1.0), -4.0 * t * (t - 1.0), 2.0 * t * (t - 0.5));
}

vec2 disp(vec2 p) {
	vec3 lu = lag(p.x);
	vec3 lv = lag(p.y);
	vec2 r0 = (m00 - vec2(0.0, 0.0)) * lu.x + (m10 - vec2(0.5, 0.0)) * lu.y + (m20 - vec2(1.0, 0.0)) * lu.z;
	vec2 r1 = (m01 - vec2(0.0, 0.5)) * lu.x + (m11 - vec2(0.5, 0.5)) * lu.y + (m21 - vec2(1.0, 0.5)) * lu.z;
	vec2 r2 = (m02 - vec2(0.0, 1.0)) * lu.x + (m12 - vec2(0.5, 1.0)) * lu.y + (m22 - vec2(1.0, 1.0)) * lu.z;
	return r0 * lv.x + r1 * lv.y + r2 * lv.z;
}

void fragment() {
	vec2 x = UV;
	for (int i = 0; i < 6; i++) {
		x = UV - disp(clamp(x, vec2(-0.5), vec2(1.5)));
	}
	bool outside = x.x < 0.0 || x.y < 0.0 || x.x > 1.0 || x.y > 1.0;
	COLOR = outside ? vec4(0.0) : texture(TEXTURE, x);
}
