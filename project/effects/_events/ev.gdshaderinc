
const int EV_NX = 16;
const int EV_NY = 9;

int ev_age_of(vec2 uv) {
	vec2 cell = clamp(floor(uv * 8.0), vec2(0.0), vec2(7.0));
	return int(cell.y) * 8 + int(cell.x);
}

vec2 ev_uv(int age, vec2 p, vec2 tsize) {
	vec2 cell = vec2(float(age % 8), float(age / 8));
	vec2 csz = max(floor(tsize / 8.0), vec2(1.0));
	return (cell * csz + clamp(p * csz, vec2(0.5), csz - 0.5)) / tsize;
}

vec4 ev_thumb(sampler2D t, int age, vec2 p) {
	return texture(t, ev_uv(age, p, vec2(textureSize(t, 0))));
}

bool ev_valid(sampler2D t, int age) {
	return age == 0 || texture(t, ev_uv(age, vec2(0.5), vec2(textureSize(t, 0)))).a > 0.5;
}

vec2 ev_point(int i, int j) {
	return vec2((float(i) + 0.5) / float(EV_NX), (float(j) + 0.5) / float(EV_NY)) * 0.92 + 0.04;
}

float ev_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 ev_stat(sampler2D s, int age) {
	vec2 sz = vec2(textureSize(s, 0));
	vec2 c = (vec2(float(age % 8), float(age / 8)) + 0.5) / 8.0;
	ivec2 px = ivec2(clamp(floor(c * sz), vec2(0.0), sz - 1.0));
	return texelFetch(s, px, 0);
}

bool ev_is_cut(sampler2D cs, int a, float thr) {
	vec4 s = ev_stat(cs, a);
	if (s.a < 0.1 || s.r < thr) {
		return false;
	}
	if ((s.a - 0.2) / 0.8 < 0.78) {
		return false;
	}
	float older = max(ev_stat(cs, a + 1).r, ev_stat(cs, a + 2).r);
	if (a == 0) {
		return s.r > max(thr + 0.06, older * 3.0 + 0.08);
	}
	float newer = ev_stat(cs, a - 1).r;
	return s.r > max(older, newer) * 2.0 + 0.08;
}

float ev_cut_threshold(float sensitivity) {
	return mix(0.6, 0.24, clamp(sensitivity, 0.0, 1.0));
}
