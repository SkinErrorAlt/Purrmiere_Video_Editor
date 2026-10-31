shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D picture : filter_linear, repeat_enable, hint_default_transparent;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int matte_from : hint_range(0, 3) = 0;
uniform int combine : hint_range(0, 3) = 0;
uniform int fit : hint_range(0, 3) = 1;
uniform float scale : hint_range(0.05, 10.0) = 1.0;
uniform vec2 position = vec2(0.5, 0.5);
uniform float rotation : hint_range(-360.0, 360.0) = 0.0;
uniform float feather : hint_range(0.0, 50.0) = 0.0;
uniform bool show_matte = false;

vec4 picture_at(vec2 uv) {
	vec2 pic = vec2(textureSize(picture, 0));
	vec2 frame = max(tex_size, vec2(1.0));
	float pa = pic.x / max(pic.y, 1.0);
	float fa = frame.x / frame.y;
	vec2 q = (uv - position) * frame;
	float r = radians(rotation);
	q = vec2(q.x * cos(r) + q.y * sin(r), -q.x * sin(r) + q.y * cos(r)) / frame;
	q /= max(scale, 0.01);
	if (fit == 0) {
		if (pa > fa) {
			q.x *= fa / pa;
		} else {
			q.y *= pa / fa;
		}
	} else if (fit == 1 || fit == 3) {
		if (pa > fa) {
			q.y *= pa / fa;
		} else {
			q.x *= fa / pa;
		}
	}
	vec2 p = q + 0.5;
	if (fit == 3) {
		p = fract(p);
	} else if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
		return vec4(0.0);
	}
	return texture(picture, p);
}

float matte_at(vec2 uv) {
	vec4 p = picture_at(uv);
	float m = p.a;
	if (matte_from >= 2) {
		m = dot(clamp(p.rgb, 0.0, 1.0), vec3(0.2126, 0.7152, 0.0722)) * p.a;
	}
	if (matte_from == 1 || matte_from == 3) {
		m = 1.0 - m;
	}
	return clamp(m, 0.0, 1.0);
}

float feathered(vec2 uv, vec2 size) {
	float m = matte_at(uv);
	float r = feather * max(px_scale, 0.0001);
	if (r > 0.5) {
		float sum = m * 2.0;
		float n = 2.0;
		float spin = fract(52.9829189 * fract(dot(uv * size, vec2(0.06711056, 0.00583715)))) * 6.28318530718;
		for (int i = 0; i < 24; i++) {
			float fi = float(i) + 0.5;
			float rr = sqrt(fi / 24.0) * r;
			float ga = fi * 2.39996323 + spin;
			sum += matte_at(uv + vec2(cos(ga), sin(ga)) * rr / size);
			n += 1.0;
		}
		m = sum / n;
	}
	return m;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	ivec2 pic_size = textureSize(picture, 0);
	vec4 c = texture(TEXTURE, UV);
	if (pic_size.x <= 4 && pic_size.y <= 4) {
		COLOR = c;
	} else {
		float m = feathered(UV, size);
		vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
		float a = c.a;
		float oa = a * m;
		if (combine == 1) {
			oa = m;
		} else if (combine == 2) {
			oa = a + m * (1.0 - a);
		} else if (combine == 3) {
			oa = a * (1.0 - m);
		}
		oa = clamp(oa, 0.0, 1.0);
		if (show_matte) {
			COLOR = vec4(vec3(oa), 1.0);
		} else {
			COLOR = vec4(rgb * oa, oa);
		}
	}
}
