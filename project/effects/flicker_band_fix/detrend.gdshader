shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float band_size : hint_range(16.0, 270.0) = 160.0;
uniform int direction = 0;

const int STRIPS = 16;
const float LOG_LO = -14.0;
const float LOG_SPAN = 14.0;
const float BAND_SPAN = 4.0;

float join16(float h, float l) {
	return (floor(h * 255.0 + 0.5) * 256.0 + floor(l * 255.0 + 0.5)) / 65535.0;
}

vec2 split16(float v) {
	float q = clamp(v, 0.0, 1.0) * 65535.0;
	float h = floor(q / 256.0);
	return vec2(h, q - h * 256.0) / 255.0;
}

vec4 read_lane(sampler2D tex, ivec2 ax, ivec2 across, int lane, int p) {
	if (lane < STRIPS) {
		vec4 t = texelFetch(tex, ax * p + across * lane, 0);
		float v = join16(t.r, t.g) * LOG_SPAN + LOG_LO;
		return vec4(v, v, v, t.b);
	}
	vec4 h = texelFetch(tex, ax * p + across * STRIPS, 0);
	vec4 l = texelFetch(tex, ax * p + across * (STRIPS + 1), 0);
	vec3 v = vec3(join16(h.r, l.r), join16(h.g, l.g), join16(h.b, l.b)) * LOG_SPAN + LOG_LO;
	return vec4(v, h.a);
}

void fragment() {
	ivec2 ax = direction == 0 ? ivec2(0, 1) : ivec2(1, 0);
	ivec2 across = ivec2(1) - ax;
	vec2 fc = floor(FRAGCOORD.xy);
	int lane = int(dot(fc, vec2(across)));
	if (lane > STRIPS + 1) {
		COLOR = vec4(0.0);
	} else {
		int pos = int(dot(fc, vec2(ax)));
		int count = int(dot(tex_size, vec2(ax)));
		vec4 me = read_lane(TEXTURE, ax, across, lane, pos);
		float sigma = max(band_size * px_scale * 0.75, 2.0);
		int reach = int(min(ceil(sigma * 2.5), float(count)));
		vec3 sum = vec3(0.0);
		float wsum = 0.0;
		for (int o = -reach; o <= reach; o++) {
			int p = pos + o;
			if (p < 0 || p >= count) {
				continue;
			}
			vec4 s = read_lane(TEXTURE, ax, across, lane, p);
			float w = exp(-0.5 * float(o * o) / (sigma * sigma)) * s.a;
			sum += s.rgb * w;
			wsum += w;
		}
		vec3 b = (me.rgb - sum / max(wsum, 0.00001)) / BAND_SPAN + 0.5;
		float cover = wsum > 0.00001 ? me.a : 0.0;
		if (lane < STRIPS) {
			COLOR = vec4(split16(b.r), cover, 1.0);
		} else {
			vec2 r = split16(b.r);
			vec2 g = split16(b.g);
			vec2 bb = split16(b.b);
			COLOR = lane == STRIPS ? vec4(r.x, g.x, bb.x, cover) : vec4(r.y, g.y, bb.y, cover);
		}
	}
}
