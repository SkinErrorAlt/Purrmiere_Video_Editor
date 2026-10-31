shader_type canvas_item;
render_mode blend_disabled;

uniform int motion : hint_range(0, 7) = 0;
uniform float angle : hint_range(0.0, 180.0) = 10.0;
uniform float distance : hint_range(0.0, 2000.0) = 30.0;
uniform float pulse : hint_range(0.0, 100.0) = 6.0;
uniform float cycles : hint_range(0.0, 10.0) = 0.5;
uniform vec2 pivot = vec2(0.5, 0.5);
uniform int ease : hint_range(0, 2) = 0;
uniform float phase : hint_range(-360.0, 360.0) = 0.0;
uniform float perspective : hint_range(0.0, 1.0) = 0.5;
uniform float motion_blur : hint_range(0.0, 1.0) = 0.5;
uniform int edges : hint_range(0, 2) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float seq_fps = 30.0;

float wave(float th) {
	if (ease == 1) {
		return 2.0 * abs(sin(3.14159265 * fract(th))) - 1.0;
	}
	if (ease == 2) {
		return 1.0 - 4.0 * abs(fract(th + 0.25) - 0.5);
	}
	return sin(6.2831853 * fract(th));
}

float lift(float th) {
	if (ease == 1) {
		return abs(sin(3.14159265 * fract(th)));
	}
	if (ease == 2) {
		return 0.5 + 0.5 * (1.0 - 4.0 * abs(fract(th) - 0.5));
	}
	return 0.5 - 0.5 * cos(6.2831853 * fract(th));
}

float turn(float th) {
	if (ease == 1) {
		float f = fract(th);
		return f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	}
	return fract(th);
}

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 1) {
		return texture(tex, fract(uv));
	}
	if (edges == 2) {
		vec2 m = 1.0 - abs(mod(uv, 2.0) - 1.0);
		return texture(tex, m);
	}
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

vec4 sample_at(sampler2D tex, vec2 uv, float t, vec2 sz, float ps) {
	float th = cycles * t + phase / 360.0;
	vec2 piv = pivot * sz;
	vec2 x = uv * sz - piv;
	float shade = 1.0;
	if (motion == 6 || motion == 7) {
		float yaw = motion == 6 ? radians(angle) * wave(th) : 6.2831853 * turn(th);
		float f = mix(6.0, 1.15, clamp(perspective, 0.0, 1.0)) * max(sz.x, sz.y);
		float c = cos(yaw);
		float s = sin(yaw);
		float den = f * c - x.x * s;
		if (abs(den) < 0.0001) {
			return vec4(0.0);
		}
		float k = f * c / den;
		if (k <= 0.0) {
			return vec4(0.0);
		}
		vec3 r = vec3(k * x.x, k * x.y, -f + k * f);
		vec2 src = vec2(r.x * c + r.z * s, r.y);
		shade = 1.0 - 0.28 * (1.0 - abs(c));
		vec4 col = fetch(tex, (src + piv) / sz);
		return vec4(col.rgb * shade, col.a);
	}
	vec2 src = x;
	if (motion == 0) {
		float r = radians(angle) * wave(th);
		src = mat2(vec2(cos(r), -sin(r)), vec2(sin(r), cos(r))) * x;
	} else if (motion == 1) {
		float r = 6.2831853 * turn(th);
		src = mat2(vec2(cos(r), -sin(r)), vec2(sin(r), cos(r))) * x;
	} else if (motion == 2) {
		float d = distance * ps;
		float off = ease == 1 ? -d * lift(th) : -d * wave(th);
		src = x - vec2(0.0, off);
	} else if (motion == 3) {
		src = x - vec2(distance * ps * wave(th), 0.0);
	} else if (motion == 4) {
		float a = 6.2831853 * turn(th);
		src = x - distance * ps * vec2(cos(a), sin(a));
	} else {
		float sc = 1.0 + pulse / 100.0 * lift(th);
		src = x / sc;
	}
	return fetch(tex, (src + piv) / sz);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fps = max(seq_fps, 1.0);
	float shutter = clamp(motion_blur, 0.0, 1.0) / fps;
	vec4 acc = vec4(0.0);
	if (shutter <= 0.00001) {
		acc = sample_at(TEXTURE, UV, clip_time, sz, ps);
	} else {
		vec3 q = fract(vec3(FRAGCOORD.xyx) * 0.1031);
		q += dot(q, q.yzx + 33.33);
		float jit = fract((q.x + q.y) * q.z);
		for (int i = 0; i < 24; i++) {
			float o = (float(i) + jit) / 24.0 - 0.5;
			acc += sample_at(TEXTURE, UV, clip_time + o * shutter, sz, ps);
		}
		acc /= 24.0;
	}
	COLOR = acc;
}
