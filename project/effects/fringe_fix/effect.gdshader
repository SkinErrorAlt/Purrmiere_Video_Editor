shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float red_shift : hint_range(-8.0, 8.0) = 0.0;
uniform float blue_shift : hint_range(-8.0, 8.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float purple : hint_range(0.0, 1.0) = 0.8;
uniform float purple_hue : hint_range(240.0, 340.0) = 285.0;
uniform float green : hint_range(0.0, 1.0) = 0.5;
uniform float green_hue : hint_range(60.0, 170.0) = 115.0;
uniform float hue_range : hint_range(10.0, 70.0) = 35.0;
uniform float width : hint_range(1.0, 12.0) = 3.0;
uniform float edge_contrast : hint_range(0.05, 1.0) = 0.3;
uniform bool show = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float luma_at(sampler2D tex, vec2 uv) {
	return dot(straight(texture(tex, clamp(uv, vec2(0.0), vec2(1.0)))), LUMA);
}

float hue_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	if (d < 0.00001) {
		return 0.0;
	}
	float h = 0.0;
	if (mx == c.r) {
		h = mod((c.g - c.b) / d, 6.0);
	} else if (mx == c.g) {
		h = (c.b - c.r) / d + 2.0;
	} else {
		h = (c.r - c.g) / d + 4.0;
	}
	return h * 60.0;
}

float near_hue(float h, float target) {
	float d = abs(mod(h - target + 180.0, 360.0) - 180.0);
	return 1.0 - smoothstep(hue_range * 0.5, hue_range * 0.5 + 12.0, d);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 d_px = (UV - centre) * size;
	vec2 far_corner = max(centre, vec2(1.0) - centre) * size;
	float r_corner = max(length(far_corner), 1.0);
	float sr = 1.0 + red_shift * px_scale / r_corner;
	float sb = 1.0 + blue_shift * px_scale / r_corner;
	vec4 cg = texture(TEXTURE, UV);
	vec4 cr = texture(TEXTURE, clamp(centre + d_px * sr / size, vec2(0.0), vec2(1.0)));
	vec4 cb = texture(TEXTURE, clamp(centre + d_px * sb / size, vec2(0.0), vec2(1.0)));
	float a = cg.a;
	vec3 rgb = vec3(straight(cr).r, straight(cg).g, straight(cb).b);
	float y = dot(rgb, LUMA);
	float lo = y;
	float hi = y;
	float reach = max(width * px_scale, 0.75);
	vec2 px = 1.0 / size;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		vec2 dir = vec2(cos(ang), sin(ang));
		float l1 = luma_at(TEXTURE, UV + dir * px * reach);
		float l2 = luma_at(TEXTURE, UV + dir * px * reach * 0.5);
		lo = min(lo, min(l1, l2));
		hi = max(hi, max(l1, l2));
	}
	float edge = smoothstep(edge_contrast * 0.6, edge_contrast, hi - lo);
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float mn = min(rgb.r, min(rgb.g, rgb.b));
	float sat_gate = smoothstep(0.03, 0.1, mx - mn);
	float h = hue_of(rgb);
	float w_purple = clamp(purple, 0.0, 1.0) * near_hue(h, purple_hue);
	float w_green = clamp(green, 0.0, 1.0) * near_hue(h, green_hue);
	float w = clamp(max(w_purple, w_green) * edge * sat_gate, 0.0, 1.0);
	vec3 fixed_rgb = mix(rgb, vec3(y), w);
	if (show) {
		fixed_rgb = mix(vec3(y * 0.35), vec3(1.0, 0.85, 0.1), w);
	}
	COLOR = vec4(clamp(fixed_rgb, 0.0, 1.0) * a, a);
}
