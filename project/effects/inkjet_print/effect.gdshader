shader_type canvas_item;
render_mode blend_disabled;

uniform float droplet : hint_range(1.0, 6.0) = 2.0;
uniform float swath : hint_range(16.0, 240.0) = 72.0;
uniform float banding : hint_range(0.0, 1.0) = 0.5;
uniform float clogs : hint_range(0.0, 1.0) = 0.4;
uniform int low_ink : hint_range(0, 4) = 1;
uniform float dry : hint_range(0.0, 1.0) = 0.45;
uniform float bleed : hint_range(0.0, 1.0) = 0.4;
uniform vec4 paper : source_color = vec4(0.96, 0.965, 0.975, 1.0);
uniform int seed : hint_range(0, 999) = 7;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec3 INK_C = vec3(0.05, 0.6, 0.92);
const vec3 INK_M = vec3(0.92, 0.12, 0.55);
const vec3 INK_Y = vec3(1.0, 0.92, 0.08);
const vec3 INK_K = vec3(0.13, 0.13, 0.14);

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec4 cmyk_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(1.0);
	rgb = mix(vec3(1.0), rgb, clamp(c.a, 0.0, 1.0));
	float k = 1.0 - max(rgb.r, max(rgb.g, rgb.b));
	float kk = k * smoothstep(0.3, 0.9, k) * 0.9;
	float d = max(1.0 - kk, 0.001);
	vec3 cmy = clamp((vec3(1.0) - rgb - kk) / d, 0.0, 1.0);
	cmy.x = min(cmy.x * 1.12, 1.0);
	return vec4(cmy, clamp(kk / 0.9, 0.0, 1.0));
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float alpha = src.a;
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 src_size = size / ps;
	vec2 P = UV * src_size;
	float sd = float(seed);
	vec2 off = vec2(sd * 7.1, sd * 3.3);
	float dsz = max(droplet, 0.5);
	float nps = max(floor(swath / dsz), 2.0);
	float row_here = floor(P.y / dsz);
	float pass_here = floor(row_here / nps);
	float shift = (h12(vec2(pass_here, sd + 1.0)) - 0.5) * banding * 0.9;
	vec2 g = vec2(P.x / dsz + shift, P.y / dsz);
	vec2 base = floor(g);
	float rad = 0.56 + bleed * 0.12;
	float soft = 0.14 + bleed * 0.26;
	float fib = vn(vec2(P.x * 0.7 + P.y * 0.2, P.y * 0.5) + off) - 0.5;
	vec4 cov = vec4(0.0);
	vec4 halo = vec4(0.0);
	vec4 lowv = vec4(0.0);
	if (low_ink > 0) {
		lowv[low_ink - 1] = 1.0;
	}
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 n = base + vec2(float(i), float(j));
			float row = n.y;
			float pass_i = floor(row / nps);
			float nozzle = row - pass_i * nps;
			float pass_dens = 1.0 + (h12(vec2(pass_i, sd + 4.0)) - 0.5) * banding * 0.22;
			float seam = nozzle < 0.5 ? (h12(vec2(pass_i, sd + 8.0)) < 0.5 ? 1.0 : -1.0) * banding : 0.0;
			float sx = (h12(vec2(pass_i, sd + 1.0)) - 0.5) * banding * 0.9;
			vec2 centre_uv = vec2((n.x + 0.5 - sx) * dsz, (n.y + 0.5) * dsz) / src_size;
			vec4 want = cmyk_at(TEXTURE, centre_uv);
			want = pow(want, vec4(1.3)) * pass_dens;
			want *= 1.0 + max(seam, 0.0) * 0.6;
			float row_streak = vn(vec2(nozzle * 0.35, pass_i * 0.13 + sd));
			float fading = 1.0 - dry * (0.55 + 0.45 * row_streak);
			want *= mix(vec4(1.0), vec4(fading), lowv);
			vec2 jit = (vec2(h12(n + off), h12(n + off + 9.0)) - 0.5) * 0.22;
			float d = length(g - (n + 0.5 + jit)) + fib * bleed * 0.25;
			float core = 1.0 - smoothstep(rad - soft, rad + soft, d);
			float wick = 1.0 - smoothstep(rad, rad + 0.35 + bleed * 0.6, d);
			for (int ch = 0; ch < 4; ch++) {
				float chf = float(ch);
				vec2 nn = n + vec2(chf * 19.0 + sd * 3.0, chf * 7.0 + sd * 5.0);
				float t = fract(fract(52.9829189 * fract(dot(nn, vec2(0.06711056, 0.00583715)))) + h12(n + off + chf * 31.0) * 0.18);
				float clogged = step(h12(vec2(nozzle, chf * 17.0 + sd * 3.0)), clogs * 0.05);
				float dropped = seam < -0.25 ? step(h12(n + chf * 5.0 + off), banding * 0.9) : 0.0;
				float live = step(t, want[ch]) * (1.0 - clogged) * (1.0 - dropped);
				cov[ch] = max(cov[ch], core * live);
				halo[ch] = max(halo[ch], wick * live);
			}
		}
	}
	cov = max(cov, halo * (0.12 + bleed * 0.22));
	vec3 col = paper.rgb * (0.985 + fib * 0.03);
	col *= mix(vec3(1.0), INK_C, cov.x);
	col *= mix(vec3(1.0), INK_M, cov.y);
	col *= mix(vec3(1.0), INK_Y, cov.z);
	col *= mix(vec3(1.0), INK_K, cov.w);
	COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
