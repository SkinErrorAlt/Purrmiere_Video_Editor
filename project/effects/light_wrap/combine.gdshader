shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D background : filter_linear, repeat_disable, hint_default_transparent;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec4 colour : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float width : hint_range(1.0, 60.0) = 24.0;
uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform int blend : hint_range(0, 3) = 0;
uniform int fit : hint_range(0, 2) = 0;
uniform float ambient : hint_range(0.0, 1.0) = 0.15;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 picture_uv(vec2 uv) {
	vec2 pic = vec2(textureSize(background, 0));
	vec2 frame = max(tex_size, vec2(1.0));
	float pa = pic.x / max(pic.y, 1.0);
	float fa = frame.x / frame.y;
	vec2 q = uv - 0.5;
	if (fit == 0) {
		if (pa > fa) {
			q.x *= fa / pa;
		} else {
			q.y *= pa / fa;
		}
	} else if (fit == 1) {
		if (pa > fa) {
			q.y *= pa / fa;
		} else {
			q.x *= fa / pa;
		}
	}
	return q + 0.5;
}

vec4 picture_at(vec2 uv) {
	vec2 p = picture_uv(uv);
	if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
		return vec4(0.0);
	}
	vec4 t = texture(background, p);
	return vec4(t.rgb * t.a, t.a);
}

vec4 picture_soft(vec2 uv, float reach_px) {
	vec2 size = max(tex_size, vec2(1.0));
	vec4 sum = picture_at(uv) * 2.0;
	float n = 2.0;
	if (reach_px > 0.5) {
		for (int i = 0; i < 16; i++) {
			float fi = float(i) + 0.5;
			float r = sqrt(fi / 16.0) * reach_px;
			float ang = fi * 2.39996323;
			sum += picture_at(uv + vec2(cos(ang), sin(ang)) * r / size);
			n += 1.0;
		}
	}
	return sum / n;
}

vec3 screen_blend(vec3 a, vec3 b) {
	return 1.0 - (1.0 - a) * (1.0 - b);
}

vec3 soft_light(vec3 a, vec3 b) {
	return mix(2.0 * a * b + a * a * (1.0 - 2.0 * b), sqrt(max(a, vec3(0.0))) * (2.0 * b - 1.0) + 2.0 * a * (1.0 - b), step(0.5, b));
}

void fragment() {
	float k = max(px_scale, 0.0001);
	vec4 orig = texture(effect_tex, UV);
	float a = orig.a;
	float a_soft = texture(TEXTURE, UV).a;
	vec3 rgb = a > 0.0001 ? clamp(orig.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 light = picture_soft(UV, width * k * 0.6);
	bool have_picture = light.a > 0.001;
	vec3 light_rgb = have_picture ? clamp(light.rgb / light.a, 0.0, 1.0) : colour.rgb;
	vec3 avg = colour.rgb;
	if (have_picture || picture_at(vec2(0.5)).a > 0.001) {
		vec4 s = vec4(0.0);
		for (int y = 0; y < 4; y++) {
			for (int x = 0; x < 4; x++) {
				s += picture_at((vec2(float(x), float(y)) + 0.5) / 4.0);
			}
		}
		if (s.a > 0.001) {
			avg = clamp(s.rgb / s.a, 0.0, 1.0);
		}
	}
	vec3 tint = avg / max(dot(avg, LUMA), 0.05);
	rgb = clamp(rgb * mix(vec3(1.0), tint, ambient), 0.0, 1.0);
	float wrap = a * clamp((1.0 - a_soft) * 2.0, 0.0, 1.0);
	wrap = clamp(wrap * strength, 0.0, 1.0);
	vec3 lit = rgb;
	if (blend == 0) {
		lit = screen_blend(rgb, light_rgb);
	} else if (blend == 1) {
		lit = min(rgb + light_rgb, vec3(1.0));
	} else if (blend == 2) {
		lit = light_rgb;
	} else {
		lit = soft_light(rgb, light_rgb);
	}
	rgb = mix(rgb, clamp(lit, 0.0, 1.0), wrap);
	COLOR = vec4(rgb * a, a);
}
