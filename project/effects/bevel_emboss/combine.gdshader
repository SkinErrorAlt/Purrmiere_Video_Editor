shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int style : hint_range(0, 3) = 0;
uniform int technique : hint_range(0, 1) = 0;
uniform float size : hint_range(1.0, 100.0) = 12.0;
uniform float depth : hint_range(0.0, 5.0) = 1.5;
uniform bool press_in = false;
uniform float light_angle : hint_range(-180.0, 180.0) = -45.0;
uniform float altitude : hint_range(0.0, 90.0) = 35.0;
uniform vec4 highlight_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float highlight_opacity : hint_range(0.0, 1.0) = 0.75;
uniform vec4 shadow_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.6;
uniform float soften : hint_range(0.0, 20.0) = 1.5;

const float DMAX = 256.0;

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

float profile(float x) {
	float t = clamp(x, 0.0, 1.0);
	return technique == 1 ? t : sin(t * 1.57079632679);
}

float height_at(sampler2D tex, vec2 uv, float s_px) {
	vec4 d = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float d_out = unpack16(d.rg);
	float d_in = unpack16(d.ba);
	float u = d_in - d_out;
	if (style == 0) {
		return profile(d_in / s_px);
	}
	if (style == 1) {
		return 1.0 - profile(d_out / s_px);
	}
	if (style == 2) {
		return profile(u / (2.0 * s_px) + 0.5);
	}
	return profile(abs(u) / s_px);
}

void fragment() {
	float k = max(px_scale, 0.0001);
	vec2 size_px = max(tex_size, vec2(1.0));
	float s_px = max(size, 1.0) * k;
	float e = (1.0 + soften) * k;
	vec2 ex = vec2(e, 0.0) / size_px;
	vec2 ey = vec2(0.0, e) / size_px;
	float hx = (height_at(TEXTURE, UV + ex, s_px) - height_at(TEXTURE, UV - ex, s_px)) / (2.0 * e);
	float hy = (height_at(TEXTURE, UV + ey, s_px) - height_at(TEXTURE, UV - ey, s_px)) / (2.0 * e);
	float lift = depth * s_px * (press_in ? -1.0 : 1.0);
	vec3 n = normalize(vec3(-hx * lift, -hy * lift, 1.0));
	float ang = radians(light_angle);
	float alt = radians(clamp(altitude, 0.0, 90.0));
	vec2 dir = vec2(sin(ang), -cos(ang));
	vec3 l = normalize(vec3(dir * cos(alt), sin(alt)));
	float shade = dot(n, l) - l.z;
	float hi = clamp(shade * 2.0, 0.0, 1.0) * highlight_opacity * highlight_colour.a;
	float sh = clamp(-shade * 2.0, 0.0, 1.0) * shadow_opacity * shadow_colour.a;
	vec4 orig = texture(effect_tex, UV);
	float a = orig.a;
	vec3 rgb = a > 0.0001 ? clamp(orig.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 lit = mix(rgb, rgb * shadow_colour.rgb, sh);
	lit = mix(lit, 1.0 - (1.0 - lit) * (1.0 - highlight_colour.rgb), hi);
	vec4 o = vec4(clamp(lit, 0.0, 1.0) * a, a);
	if (style != 0) {
		float outer = 1.0 - a;
		float oa = 1.0 - (1.0 - hi) * (1.0 - sh);
		vec3 oc = highlight_colour.rgb * hi + shadow_colour.rgb * sh * (1.0 - hi);
		vec4 around = vec4(oc, oa) * outer;
		o = o + around * (1.0 - o.a);
	}
	COLOR = clamp(o, 0.0, 1.0);
}
