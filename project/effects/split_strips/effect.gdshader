shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D blur1 : filter_linear, repeat_disable;
uniform sampler2D blur2 : filter_linear, repeat_disable;
uniform sampler2D blur3 : filter_linear, repeat_disable;
uniform sampler2D blur4 : filter_linear, repeat_disable;
uniform sampler2D blur5 : filter_linear, repeat_disable;
uniform int strips : hint_range(2, 6) = 3;
uniform int direction : hint_range(0, 1) = 0;
uniform int content : hint_range(0, 1) = 0;
uniform float gap : hint_range(0.0, 200.0) = 8.0;
uniform vec4 gap_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float blur : hint_range(0.0, 120.0) = 0.0;
uniform bool mirror = false;
uniform bool mono = false;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 tap(sampler2D t, vec2 uv) {
	return texture(t, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec4 level(int l, vec2 uv) {
	if (l <= 0) { return tap(effect_tex, uv); }
	if (l == 1) { return tap(blur1, uv); }
	if (l == 2) { return tap(blur2, uv); }
	if (l == 3) { return tap(blur3, uv); }
	if (l == 4) { return tap(blur4, uv); }
	return tap(blur5, uv);
}

vec4 soft(int l, vec2 uv, vec2 full) {
	if (l <= 0) {
		return tap(effect_tex, uv);
	}
	vec2 o = exp2(float(l)) / full;
	vec4 s = level(l, uv) * 0.4;
	s += level(l, uv + vec2(o.x, 0.0)) * 0.15;
	s += level(l, uv - vec2(o.x, 0.0)) * 0.15;
	s += level(l, uv + vec2(0.0, o.y)) * 0.15;
	s += level(l, uv - vec2(0.0, o.y)) * 0.15;
	return s;
}

vec4 picture(vec2 uv, float radius, vec2 full) {
	if (radius < 0.5) {
		return tap(effect_tex, uv);
	}
	float lf = clamp(log2(radius / 1.2) + 1.0, 0.0, 5.0);
	int l0 = int(floor(lf));
	float f = lf - float(l0);
	vec4 a = soft(l0, uv, full);
	vec4 b = soft(min(l0 + 1, 5), uv, full);
	return mix(a, b, f);
}

void fragment() {
	vec2 cells = max(tex_size, vec2(1.0));
	vec2 full = max(1.0 / max(abs(vec2(dFdx(UV.x), dFdy(UV.y))), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * full.x / cells.x, 0.0001);
	vec2 p = UV * full;
	int n = clamp(strips, 2, 6);
	float fn = float(n);
	bool rows = direction == 0;
	float along = rows ? p.y : p.x;
	float total = rows ? full.y : full.x;
	float g = min(gap * ps, total / fn * 0.8);
	float len = (total - (fn - 1.0) * g) / fn;
	float idx = clamp(floor(along / (len + g)), 0.0, fn - 1.0);
	float local = along - idx * (len + g);
	vec4 gc = vec4(gap_colour.rgb * gap_colour.a, gap_colour.a);
	if (local > len) {
		COLOR = gc;
	} else {
		vec2 sdim = rows ? vec2(full.x, len) : vec2(len, full.y);
		vec2 lp = rows ? vec2(p.x, local) : vec2(local, p.y);
		bool odd = mod(idx, 2.0) > 0.5;
		if (mirror && odd) {
			lp.x = sdim.x - lp.x;
		}
		vec2 src;
		bool inside = true;
		if (content == 0) {
			float k = max(sdim.x / full.x, sdim.y / full.y);
			vec2 region = sdim / k;
			vec2 c = clamp(centre * full, region * 0.5, full - region * 0.5);
			src = c - region * 0.5 + lp / k;
		} else {
			float k = min(sdim.x / full.x, sdim.y / full.y);
			vec2 shown = full * k;
			vec2 off = (sdim - shown) * 0.5;
			src = (lp - off) / k;
			inside = all(greaterThanEqual(lp, off)) && all(lessThanEqual(lp, off + shown));
		}
		if (!inside) {
			COLOR = gc;
		} else {
			bool outer = n >= 3 && (idx < 0.5 || idx > fn - 1.5);
			vec4 c = picture(src / full, outer ? blur * ps : 0.0, full);
			if (mono && odd) {
				float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
				c.rgb = vec3(y);
			}
			COLOR = c;
		}
	}
}
