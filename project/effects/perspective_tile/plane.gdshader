shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D mip1 : filter_linear, repeat_disable;
uniform sampler2D mip2 : filter_linear, repeat_disable;
uniform sampler2D mip3 : filter_linear, repeat_disable;
uniform sampler2D mip4 : filter_linear, repeat_disable;
uniform sampler2D mip5 : filter_linear, repeat_disable;
uniform float tilt : hint_range(0.0, 89.0) = 72.0;
uniform float turn : hint_range(-180.0, 180.0) = 0.0;
uniform float height : hint_range(0.1, 5.0) = 1.0;
uniform float tile_size : hint_range(0.05, 8.0) = 2.0;
uniform bool mirror = false;
uniform float scroll : hint_range(-10.0, 10.0) = 0.0;
uniform float horizon : hint_range(0.0, 1.0) = 0.35;
uniform vec4 fog_colour : source_color = vec4(0.06, 0.07, 0.11, 1.0);
uniform float fog : hint_range(0.0, 1.0) = 0.5;
uniform vec2 seq_size = vec2(1920.0, 1080.0);
uniform float time = 0.0;

vec4 level(int k, vec2 uv) {
	if (k <= 0) {
		return textureLod(effect_tex, uv, 0.0);
	} else if (k == 1) {
		return textureLod(mip1, uv, 0.0);
	} else if (k == 2) {
		return textureLod(mip2, uv, 0.0);
	} else if (k == 3) {
		return textureLod(mip3, uv, 0.0);
	} else if (k == 4) {
		return textureLod(mip4, uv, 0.0);
	}
	return textureLod(mip5, uv, 0.0);
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float asp = full.x / max(full.y, 1.0);
	float F = 1.2;
	float t = radians(clamp(tilt, 0.0, 89.0));
	vec3 n = vec3(0.0, sin(t), -cos(t));
	float D = 2.0;
	vec3 Q = vec3(0.0, -max(height, 0.01), D);
	float sy_nat = -F * cos(t) / max(sin(t), 0.0001);
	float shift = clamp(sy_nat - (horizon - 0.5), -0.6, 0.6);
	vec2 sc = vec2((UV.x - 0.5) * asp, UV.y - 0.5 + shift);
	vec3 d = vec3(sc.x, -sc.y, F);
	float dn = dot(d, n);
	float qn = dot(Q, n);
	float s = dn < -0.000001 ? qn / dn : -1.0;
	bool hit = s > 0.0;
	vec3 P = d * max(s, 0.0);
	vec3 e1 = vec3(1.0, 0.0, 0.0);
	vec3 e2 = cross(e1, n);
	vec3 L = P - Q;
	vec2 pp = vec2(dot(L, e1), dot(L, e2));
	float tr = radians(turn);
	pp = vec2(cos(tr) * pp.x + sin(tr) * pp.y, -sin(tr) * pp.x + cos(tr) * pp.y);
	vec2 tc = pp / (max(tile_size, 0.01) * vec2(asp, 1.0)) + vec2(0.5, 0.5);
	tc.y += scroll * time;
	vec2 dx = dFdx(tc) * full;
	vec2 dy = dFdy(tc) * full;
	float fp = max(length(dx), length(dy));
	float lod = clamp(log2(max(fp, 0.0001)) - 0.25, 0.0, 5.0);
	vec2 cell = floor(tc);
	vec2 f = tc - cell;
	if (mirror) {
		if (mod(cell.x, 2.0) > 0.5) {
			f.x = 1.0 - f.x;
		}
		if (mod(cell.y, 2.0) > 0.5) {
			f.y = 1.0 - f.y;
		}
	}
	vec2 uv = vec2(f.x, 1.0 - f.y);
	int l0 = int(floor(lod));
	float lf = lod - float(l0);
	vec4 c = mix(level(l0, uv), level(min(l0 + 1, 5), uv), lf);
	float far = smoothstep(4.3, 6.5, log2(max(fp, 0.0001)));
	if (far > 0.0) {
		vec4 avg = vec4(0.0);
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				avg += textureLod(mip5, (vec2(float(i), float(j)) + 0.5) / 4.0, 0.0);
			}
		}
		c = mix(c, avg / 16.0, far);
	}
	float dist = s * length(d);
	float fg = clamp(fog, 0.0, 1.0);
	float ff = hit ? 1.0 - exp(-dist * fg * fg * 0.12) : 1.0;
	vec4 fc = vec4(fog_colour.rgb * fog_colour.a, fog_colour.a);
	COLOR = hit ? mix(c, fc * c.a, ff) : fc;
}
