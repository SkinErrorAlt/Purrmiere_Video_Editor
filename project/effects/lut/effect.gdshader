shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D lut : filter_nearest, repeat_disable, hint_default_transparent;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform int interpolation : hint_range(0, 1) = 0;

int cube_size(ivec2 ts) {
	if (ts.y >= 2 && ts.x == ts.y * ts.y) {
		return ts.y;
	}
	if (ts.x == ts.y && ts.x >= 8) {
		int level = int(round(pow(float(ts.x), 1.0 / 3.0)));
		if (level * level * level == ts.x) {
			return level * level;
		}
	}
	return 0;
}

vec3 cell(ivec3 i, int n, ivec2 ts) {
	ivec3 c = clamp(i, ivec3(0), ivec3(n - 1));
	ivec2 xy;
	if (ts.x == ts.y) {
		int idx = c.x + c.y * n + c.z * n * n;
		xy = ivec2(idx % ts.x, idx / ts.x);
	} else {
		xy = ivec2(c.x + c.z * n, c.y);
	}
	return texelFetch(lut, xy, 0).rgb;
}

vec3 trilinear(vec3 col, int n, ivec2 ts) {
	vec3 p = clamp(col, 0.0, 1.0) * float(n - 1);
	ivec3 i0 = ivec3(floor(p));
	vec3 f = p - vec3(i0);
	vec3 c000 = cell(i0, n, ts);
	vec3 c100 = cell(i0 + ivec3(1, 0, 0), n, ts);
	vec3 c010 = cell(i0 + ivec3(0, 1, 0), n, ts);
	vec3 c110 = cell(i0 + ivec3(1, 1, 0), n, ts);
	vec3 c001 = cell(i0 + ivec3(0, 0, 1), n, ts);
	vec3 c101 = cell(i0 + ivec3(1, 0, 1), n, ts);
	vec3 c011 = cell(i0 + ivec3(0, 1, 1), n, ts);
	vec3 c111 = cell(i0 + ivec3(1, 1, 1), n, ts);
	vec3 x00 = mix(c000, c100, f.x);
	vec3 x10 = mix(c010, c110, f.x);
	vec3 x01 = mix(c001, c101, f.x);
	vec3 x11 = mix(c011, c111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

vec3 tetrahedral(vec3 col, int n, ivec2 ts) {
	vec3 p = clamp(col, 0.0, 1.0) * float(n - 1);
	ivec3 i0 = ivec3(floor(p));
	vec3 f = p - vec3(i0);
	vec3 c000 = cell(i0, n, ts);
	vec3 c111 = cell(i0 + ivec3(1, 1, 1), n, ts);
	if (f.x > f.y) {
		if (f.y > f.z) {
			return (1.0 - f.x) * c000 + (f.x - f.y) * cell(i0 + ivec3(1, 0, 0), n, ts) + (f.y - f.z) * cell(i0 + ivec3(1, 1, 0), n, ts) + f.z * c111;
		}
		if (f.x > f.z) {
			return (1.0 - f.x) * c000 + (f.x - f.z) * cell(i0 + ivec3(1, 0, 0), n, ts) + (f.z - f.y) * cell(i0 + ivec3(1, 0, 1), n, ts) + f.y * c111;
		}
		return (1.0 - f.z) * c000 + (f.z - f.x) * cell(i0 + ivec3(0, 0, 1), n, ts) + (f.x - f.y) * cell(i0 + ivec3(1, 0, 1), n, ts) + f.y * c111;
	}
	if (f.z > f.y) {
		return (1.0 - f.z) * c000 + (f.z - f.y) * cell(i0 + ivec3(0, 0, 1), n, ts) + (f.y - f.x) * cell(i0 + ivec3(0, 1, 1), n, ts) + f.x * c111;
	}
	if (f.z > f.x) {
		return (1.0 - f.y) * c000 + (f.y - f.z) * cell(i0 + ivec3(0, 1, 0), n, ts) + (f.z - f.x) * cell(i0 + ivec3(0, 1, 1), n, ts) + f.x * c111;
	}
	return (1.0 - f.y) * c000 + (f.y - f.x) * cell(i0 + ivec3(0, 1, 0), n, ts) + (f.x - f.z) * cell(i0 + ivec3(1, 1, 0), n, ts) + f.z * c111;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	ivec2 ts = textureSize(lut, 0);
	int n = cube_size(ts);
	if (n >= 2 && texelFetch(lut, ivec2(0, 0), 0).a > 0.0) {
		vec3 graded = interpolation == 1 ? trilinear(rgb, n, ts) : tetrahedral(rgb, n, ts);
		rgb = mix(rgb, graded, clamp(intensity, 0.0, 1.0));
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
