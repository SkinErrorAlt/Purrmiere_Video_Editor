shader_type canvas_item;

uniform float floor_db = -100.0;
uniform float range_db = 90.0;
uniform int cmap = 0;

vec3 inferno(float t) {
	const vec3 c0 = vec3(0.0002189403691192265, 0.001651004631001012, -0.01948089843709184);
	const vec3 c1 = vec3(0.1065134194856116, 0.5639564367884091, 3.932712388889277);
	const vec3 c2 = vec3(11.60249308247187, -3.972853965665698, -15.9423941062914);
	const vec3 c3 = vec3(-41.70399613139459, 17.43639888205313, 44.35414519872813);
	const vec3 c4 = vec3(77.162935699427, -33.40235894210092, -81.80730925738993);
	const vec3 c5 = vec3(-71.31942824499214, 32.62606426397723, 73.20951985803202);
	const vec3 c6 = vec3(25.13112622477341, -12.24266895238567, -23.07032500287172);
	return c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6)))));
}

vec3 magma(float t) {
	const vec3 c0 = vec3(-0.002136485053939582, -0.000749655052795221, -0.005386127855323933);
	const vec3 c1 = vec3(0.2516605407371642, 0.6775232436837668, 2.494026599312351);
	const vec3 c2 = vec3(8.353717279216625, -3.577719514958484, 0.3144679030132573);
	const vec3 c3 = vec3(-27.66873308576866, 14.26473078096533, -13.64921318813922);
	const vec3 c4 = vec3(52.17613981234068, -27.94360607168351, 12.94416944238394);
	const vec3 c5 = vec3(-50.76852536473588, 29.04658282127291, 4.23415299384598);
	const vec3 c6 = vec3(18.65570506591883, -11.48977351997711, -5.601961508734096);
	return c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6)))));
}

vec3 viridis(float t) {
	const vec3 c0 = vec3(0.2777273272234177, 0.005407344544966578, 0.3340998053353061);
	const vec3 c1 = vec3(0.1050930431085774, 1.404613529898575, 1.384590162594685);
	const vec3 c2 = vec3(-0.3308618287255563, 0.214847559468213, 0.09509516302823659);
	const vec3 c3 = vec3(-4.634230498983486, -5.799100973351585, -19.33244095627987);
	const vec3 c4 = vec3(6.228269936347081, 14.17993336680509, 56.69055260068105);
	const vec3 c5 = vec3(4.776384997670288, -13.74514537774601, -65.35303263337234);
	const vec3 c6 = vec3(-5.435455855934631, 4.645852612178535, 26.3124352495832);
	return c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6)))));
}

vec3 classic(float t) {
	vec3 a = vec3(0.0, 0.0, 0.0);
	vec3 b = vec3(0.05, 0.05, 0.45);
	vec3 c = vec3(0.55, 0.0, 0.6);
	vec3 d = vec3(0.95, 0.15, 0.1);
	vec3 e = vec3(1.0, 0.85, 0.1);
	vec3 f = vec3(1.0, 1.0, 1.0);
	float s = t * 5.0;
	if (s < 1.0) return mix(a, b, s);
	if (s < 2.0) return mix(b, c, s - 1.0);
	if (s < 3.0) return mix(c, d, s - 2.0);
	if (s < 4.0) return mix(d, e, s - 3.0);
	return mix(e, f, s - 4.0);
}

void fragment() {
	float db = texture(TEXTURE, UV).r;
	float v = clamp((db - floor_db) / max(range_db, 1.0), 0.0, 1.0);
	vec3 col;
	if (cmap == 1) {
		col = magma(v);
	} else if (cmap == 2) {
		col = viridis(v);
	} else if (cmap == 3) {
		col = classic(v);
	} else if (cmap == 4) {
		col = vec3(v);
	} else {
		col = inferno(v);
	}
	if (db < -900.0) {
		col = vec3(0.0);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
