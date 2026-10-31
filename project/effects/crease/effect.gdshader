shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float fold : hint_range(0.0, 85.0) = 25.0;
uniform int kind = 0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float crease_width : hint_range(0.0, 60.0) = 6.0;
uniform int edges = 2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 1) {
		uv = 1.0 - abs(1.0 - mod(uv, 2.0));
	} else if (edges == 2) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec2 aspect = vec2(dims.x / dims.y, 1.0);
	float a = radians(angle);
	vec2 along = vec2(sin(a), -cos(a));
	vec2 across = vec2(cos(a), sin(a));
	vec2 d = (UV - centre) * aspect;
	float xp = dot(d, across);
	float yp = dot(d, along);
	float phi = radians(clamp(fold, 0.0, 85.0));
	float sn = sin(phi);
	float cs = cos(phi);
	float cam = 2.5;
	float ax = abs(xp);
	float x = 0.0;
	float z = 0.0;
	bool lost = false;
	if (kind == 0) {
		float den = cam * cs - ax * sn;
		if (den <= 0.0001) {
			lost = true;
		} else {
			x = ax * cam / den;
			z = x * sn;
		}
	} else {
		x = ax * cam / (cam * cs + ax * sn);
		z = -x * sn;
	}
	vec4 c = vec4(0.0);
	if (!lost) {
		float y = yp * (cam + z) / cam;
		vec2 q = across * sign(xp) * x + along * y;
		c = fetch(TEXTURE, centre + q / aspect);
	}
	float sh = clamp(shading, 0.0, 1.0) * sn;
	float side = xp < 0.0 ? 1.0 : -1.0;
	if (kind == 1) {
		side = -side;
	}
	float light = side > 0.0 ? 1.0 + 0.3 * sh : 1.0 - 0.55 * sh;
	float wpx = max(crease_width * max(px_scale, 0.0001), 0.0);
	if (wpx > 0.0) {
		float dpx = abs(xp) * dims.y;
		float g = clamp(1.0 - dpx / wpx, 0.0, 1.0);
		g = g * g;
		light *= kind == 0 ? 1.0 - 0.9 * sh * g : 1.0 + 0.45 * sh * g;
	}
	COLOR = vec4(min(c.rgb * light, vec3(c.a)), c.a);
}
