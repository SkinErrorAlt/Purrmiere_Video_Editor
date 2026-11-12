extends RefCounted
## GLSL compute sources for the spectrogram (a batched Stockham FFT over view columns) and for hiding a picture
## in sound (a bank of sines driven by the picture's rows).

const FFT := """
#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D samples;
layout(set = 0, binding = 1, std430) readonly buffer WinBuf { float win[]; };
layout(set = 0, binding = 2, std430) readonly buffer TwBuf { vec2 tw[]; };
layout(set = 0, binding = 3, std430) buffer ABuf { vec2 buf_a[]; };
layout(set = 0, binding = 4, std430) buffer BBuf { vec2 buf_b[]; };
layout(set = 0, binding = 5, r32f) uniform writeonly image2D out_img;
layout(set = 0, binding = 6, std430) readonly buffer ColBuf { int col_start[]; };

layout(push_constant, std430) uniform Params {
	int mode;
	int n;
	int log2n;
	int stage;
	int pairs;
	int col0;
	int cols;
	int height;
	int tex_w;
	int count;
	int from_b;
	int log_freq;
	float f0;
	float f1;
	float rate;
	float norm2;
} pc;

const uint ROW = 65535u * 256u;

float sample_at(int i) {
	if (i < 0 || i >= pc.count) {
		return 0.0;
	}
	return imageLoad(samples, ivec2(i % pc.tex_w, i / pc.tex_w)).r;
}

float column_sample(int col, int k) {
	if (col >= pc.cols) {
		return 0.0;
	}
	return sample_at(col_start[col] + k);
}

vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 read_res(uint i) {
	return pc.from_b == 1 ? buf_b[i] : buf_a[i];
}

float power_at(uint base, int k, int which) {
	if (k < 0 || k > pc.n / 2) {
		return 0.0;
	}
	vec2 z = read_res(base + uint(k));
	vec2 zc = read_res(base + uint((pc.n - k) & (pc.n - 1)));
	zc.y = -zc.y;
	vec2 d = which == 0 ? (z + zc) : (z - zc);
	return 0.25 * dot(d, d);
}

float freq_at(float v) {
	if (pc.log_freq == 1) {
		return pc.f0 * pow(pc.f1 / pc.f0, v);
	}
	return mix(pc.f0, pc.f1, v);
}

void main() {
	uint g = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * ROW;
	uint un = uint(pc.n);
	if (pc.mode == 0) {
		if (g >= uint(pc.pairs) * un) {
			return;
		}
		uint p = g / un;
		int k = int(g % un);
		int ca = pc.col0 + int(p) * 2;
		float w = win[k];
		buf_a[g] = vec2(column_sample(ca, k) * w, column_sample(ca + 1, k) * w);
		return;
	}
	if (pc.mode == 1) {
		uint half_n = un / 2u;
		if (g >= uint(pc.pairs) * half_n) {
			return;
		}
		uint p = g / half_n;
		uint j = g % half_n;
		uint s = uint(pc.stage);
		uint ns = 1u << s;
		uint k = j & (ns - 1u);
		uint m = k << (uint(pc.log2n) - 1u - s);
		uint base = p * un;
		uint dst = ((j >> s) << (s + 1u)) + k;
		vec2 a;
		vec2 b;
		if ((s & 1u) == 0u) {
			a = buf_a[base + j];
			b = cmul(buf_a[base + j + half_n], tw[m]);
			buf_b[base + dst] = a + b;
			buf_b[base + dst + ns] = a - b;
		} else {
			a = buf_b[base + j];
			b = cmul(buf_b[base + j + half_n], tw[m]);
			buf_a[base + dst] = a + b;
			buf_a[base + dst + ns] = a - b;
		}
		return;
	}
	uint h = uint(pc.height);
	if (g >= uint(pc.pairs) * 2u * h) {
		return;
	}
	int xb = int(g / h);
	int y = int(g % h);
	int x = pc.col0 + xb;
	if (x >= pc.cols) {
		return;
	}
	uint base = uint(xb / 2) * un;
	int which = xb & 1;
	float hf = float(pc.height);
	float v_lo = (hf - 1.0 - float(y)) / hf;
	float v_hi = (hf - float(y)) / hf;
	float v_mid = (hf - 0.5 - float(y)) / hf;
	float to_bin = float(pc.n) / pc.rate;
	float k_lo = freq_at(v_lo) * to_bin;
	float k_hi = freq_at(v_hi) * to_bin;
	float pw = 0.0;
	if (k_hi - k_lo <= 1.0) {
		float kc = freq_at(v_mid) * to_bin;
		float k0 = floor(kc);
		float fr = kc - k0;
		pw = mix(power_at(base, int(k0), which), power_at(base, int(k0) + 1, which), fr);
	} else {
		int a = int(ceil(k_lo));
		int b = int(floor(k_hi));
		int step = max(1, (b - a) / 2048);
		for (int k = a; k <= b; k += step) {
			pw = max(pw, power_at(base, k, which));
		}
	}
	int ix = pc.col0 + xb;
	bool outside = col_start[ix] + pc.n <= 0 || col_start[ix] >= pc.count;
	float db = outside ? -999.0 : 10.0 * log(max(pw / pc.norm2, 1e-30)) / log(10.0);
	imageStore(out_img, ivec2(x, y), vec4(db, 0.0, 0.0, 0.0));
}
"""

const SYNTH := """
#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer AmpBuf { float amp[]; };
layout(set = 0, binding = 1, std430) readonly buffer StepBuf { uint fstep[]; };
layout(set = 0, binding = 2, std430) readonly buffer PhaseBuf { float phase[]; };
layout(set = 0, binding = 3, std430) buffer OutBuf { float outs[]; };
layout(set = 0, binding = 4, std430) buffer MaxBuf { float gmax[]; };

layout(push_constant, std430) uniform Params {
	int mode;
	int rows;
	int cols;
	int count;
	float per_col;
	float fade;
	float scale;
	int first;
	int chunk;
	int pad0;
	int pad1;
	int pad2;
} pc;

const uint ROW = 65535u * 256u;
shared float part[256];

void main() {
	uint g = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * ROW;
	if (pc.mode == 0) {
		uint i = g + uint(pc.first);
		if (g >= uint(pc.chunk) || i >= uint(pc.count)) {
			return;
		}
		float u = (float(i) + 0.5) / pc.per_col - 0.5;
		float c0f = clamp(floor(u), 0.0, float(pc.cols - 1));
		float fr = clamp(u - floor(u), 0.0, 1.0);
		if (u < 0.0) {
			fr = 0.0;
		}
		fr = fr * fr * (3.0 - 2.0 * fr);
		int c0 = int(c0f);
		int c1 = min(c0 + 1, pc.cols - 1);
		float sum = 0.0;
		for (int r = 0; r < pc.rows; r++) {
			float a = mix(amp[c0 * pc.rows + r], amp[c1 * pc.rows + r], fr);
			if (a > 0.0) {
				uint cyc = (fstep[r] * i) & 1048575u;
				sum += a * sin(6.28318530718 * (float(cyc) / 1048576.0) + phase[r]);
			}
		}
		float total = float(pc.count);
		float env = clamp(min(float(i), total - 1.0 - float(i)) / max(pc.fade, 1.0), 0.0, 1.0);
		outs[i] = sum * env;
		return;
	}
	if (pc.mode == 1) {
		uint lid = gl_LocalInvocationID.x;
		part[lid] = g < uint(pc.count) ? abs(outs[g]) : 0.0;
		barrier();
		for (uint s = 128u; s > 0u; s >>= 1u) {
			if (lid < s) {
				part[lid] = max(part[lid], part[lid + s]);
			}
			barrier();
		}
		if (lid == 0u) {
			gmax[g / 256u] = part[0];
		}
		return;
	}
	if (g < uint(pc.count)) {
		outs[g] = outs[g] * pc.scale;
	}
}
"""
