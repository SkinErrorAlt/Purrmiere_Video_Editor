
const int FP_GRID = 8;
const int FP_MAX_PAIRS = 61;
const int FP_NX = 256;
const int FP_NY = 144;
const int FP_SMAX = 48;
const float FP_DRANGE = 0.25;
const float FP_XRANGE = 0.5;
const float FP_VRANGE = 8.0;

vec2 fp_pack(float v) {
	float q = clamp(round(clamp(v, 0.0, 1.0) * 65535.0), 0.0, 65535.0);
	float hi = floor(q / 256.0);
	return vec2(hi, q - hi * 256.0) / 255.0;
}

float fp_unpack(vec2 c) {
	return (round(c.x * 255.0) * 256.0 + round(c.y * 255.0)) / 65535.0;
}

vec4 fp_pack2(vec2 v, float range) {
	vec2 n = clamp(v / (2.0 * range) + 0.5, vec2(0.0), vec2(1.0));
	return vec4(fp_pack(n.x), fp_pack(n.y));
}

vec2 fp_unpack2(vec4 c, float range) {
	vec2 n = vec2(fp_unpack(c.rg), fp_unpack(c.ba));
	vec2 q = vec2(round(c.r * 255.0) * 256.0 + round(c.g * 255.0), round(c.b * 255.0) * 256.0 + round(c.a * 255.0));
	vec2 v = (n - 0.5) * 2.0 * range;
	return mix(v, vec2(0.0), vec2(equal(q, vec2(32768.0))));
}

vec2 fp_out_size(vec2 uv) {
	return max(round(1.0 / max(abs(vec2(dFdx(uv.x), dFdy(uv.y))), vec2(1e-6))), vec2(1.0));
}

ivec2 fp_tile_size(ivec2 atlas) {
	return max(atlas / FP_GRID, ivec2(2));
}

ivec2 fp_tile_origin(int age, ivec2 ts) {
	return ivec2(age % FP_GRID, age / FP_GRID) * ts;
}

float fp_luma(sampler2D atlas, int age, ivec2 p, ivec2 ts) {
	ivec2 q = clamp(p, ivec2(0), ts - ivec2(1));
	return fp_unpack(texelFetch(atlas, fp_tile_origin(age, ts) + q, 0).rg);
}

bool fp_tile_ok(sampler2D atlas, int age, ivec2 ts) {
	return texelFetch(atlas, fp_tile_origin(age, ts), 0).b > 0.5;
}

float fp_luma_bl(sampler2D atlas, int age, vec2 q, ivec2 ts) {
	vec2 p = q - 0.5;
	vec2 f = fract(p);
	ivec2 i = ivec2(floor(p));
	float a = fp_luma(atlas, age, i, ts);
	float b = fp_luma(atlas, age, i + ivec2(1, 0), ts);
	float c = fp_luma(atlas, age, i + ivec2(0, 1), ts);
	float d = fp_luma(atlas, age, i + ivec2(1, 1), ts);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 fp_motion(sampler2D glob, int a) {
	return fp_unpack2(texelFetch(glob, ivec2(a, 0), 0), FP_DRANGE);
}

int fp_pairs(sampler2D glob) {
	return int(round(texelFetch(glob, ivec2(0, 1), 0).r * 255.0));
}

float fp_kernel(float tau, float w, float zw) {
	float wd = sqrt(max(w * w - zw * zw, 0.04));
	return exp(-zw * tau) * sin(wd * tau) / wd;
}

float fp_kernel_rate(float tau, float w, float zw) {
	float wd = sqrt(max(w * w - zw * zw, 0.04));
	return exp(-zw * tau) * (cos(wd * tau) - zw / wd * sin(wd * tau));
}

vec2 fp_spring(float hz, float settle) {
	float w = 6.2831853 * max(hz, 0.05);
	float zw = 4.6 / max(settle, 0.05);
	return vec2(w, min(zw, w * 1.2));
}

vec4 fp_respond(sampler2D glob, int pairs, float fps, vec2 wz, vec2 gain) {
	vec2 x = vec2(0.0);
	vec2 v = vec2(0.0);
	if (pairs < 2) {
		return vec4(0.0);
	}
	float span = float(pairs) / fps;
	vec2 nxt = fp_motion(glob, 0);
	for (int a = 0; a < FP_MAX_PAIRS; a++) {
		if (a >= pairs - 1) {
			break;
		}
		vec2 older = fp_motion(glob, a + 1);
		vec2 dv = (nxt - older) * fps * gain;
		nxt = older;
		if (dv.x == 0.0 && dv.y == 0.0) {
			continue;
		}
		float tau = float(a + 1) / fps;
		float taper = 1.0 - smoothstep(span * 0.6, span, tau);
		x += dv * (fp_kernel(tau, wz.x, wz.y) * taper);
		v += dv * (fp_kernel_rate(tau, wz.x, wz.y) * taper);
	}
	return vec4(x, v);
}

vec2 fp_x(sampler2D spr, int k) {
	return fp_unpack2(texelFetch(spr, ivec2(k, 0), 0), FP_XRANGE);
}

vec2 fp_v(sampler2D spr, int k) {
	return fp_unpack2(texelFetch(spr, ivec2(k, 1), 0), FP_VRANGE);
}

vec2 fp_mirror(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return mix(m, 2.0 - m, step(1.0, m));
}

const float FP_FRANGE = 0.06;

ivec2 fp_flow_size(ivec2 atlas) {
	return max(fp_tile_size(atlas) / 4, ivec2(2));
}

vec4 fp_flow_pack(vec2 v, float energy, float trust) {
	vec2 q = clamp(round(v / FP_FRANGE * 127.0) + 128.0, vec2(1.0), vec2(255.0));
	return vec4(q / 255.0, clamp(energy, 0.0, 1.0), clamp(trust, 0.0, 1.0));
}

float fp_flow_trust(sampler2D flow, int a, ivec2 p, ivec2 fs) {
	return texelFetch(flow, fp_tile_origin(a, fs) + clamp(p, ivec2(0), fs - ivec2(1)), 0).a;
}

vec3 fp_flow(sampler2D flow, int a, ivec2 p, ivec2 fs) {
	vec4 c = texelFetch(flow, fp_tile_origin(a, fs) + clamp(p, ivec2(0), fs - ivec2(1)), 0);
	vec2 q = round(c.rg * 255.0) - 128.0;
	return vec3(q / 127.0 * FP_FRANGE, c.b);
}

vec2 fp_field_raw(sampler2D field, ivec2 p, ivec2 fs, int which, float range) {
	ivec2 q = clamp(p, ivec2(0), fs - ivec2(1)) + ivec2(which * fs.x, 0);
	return fp_unpack2(texelFetch(field, q, 0), range);
}

vec2 fp_field(sampler2D field, vec2 uv, ivec2 fs, int which, float range) {
	vec2 g = uv * vec2(fs) - 0.5;
	vec2 i = floor(g);
	vec2 f = g - i;
	vec2 w0 = (1.0 - f) * (1.0 - f) * (1.0 - f) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f * f + 3.0 * f * f * f) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f * f - 3.0 * f * f * f) / 6.0;
	vec2 w3 = f * f * f / 6.0;
	vec2 acc = vec2(0.0);
	for (int y = 0; y < 4; y++) {
		float wy = y == 0 ? w0.y : (y == 1 ? w1.y : (y == 2 ? w2.y : w3.y));
		for (int x = 0; x < 4; x++) {
			float wx = x == 0 ? w0.x : (x == 1 ? w1.x : (x == 2 ? w2.x : w3.x));
			acc += fp_field_raw(field, ivec2(i) + ivec2(x - 1, y - 1), fs, which, range) * (wx * wy);
		}
	}
	return acc;
}

vec4 fp_field_camera(sampler2D field, ivec2 fs) {
	return vec4(fp_unpack2(texelFetch(field, ivec2(0, fs.y), 0), FP_XRANGE), fp_unpack2(texelFetch(field, ivec2(1, fs.y), 0), FP_VRANGE));
}

float fp_prof(sampler2D prof, int age, int i, bool cols) {
	return fp_unpack(texelFetch(prof, ivec2(i, cols ? age : age + 64), 0).rg);
}
