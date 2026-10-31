shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.0, 0.5) = 0.12;
uniform float swirl : hint_range(-720.0, 720.0) = 0.0;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform int edges = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

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
	vec2 aspect = vec2(max(tex_size.x, 1.0) / max(tex_size.y, 1.0), 1.0);
	vec2 d = (UV - centre) * aspect;
	float r = length(d);
	float a = max(size, 0.0);
	if (a < 0.00001) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float rs = max(r, 0.0001);
		float src_r = rs + a * a / rs;
		float turn = radians(swirl) * min(a * a / (rs * rs), 1.0);
		float cs = cos(turn);
		float sn = sin(turn);
		vec2 dir = d / rs;
		dir = vec2(dir.x * cs - dir.y * sn, dir.x * sn + dir.y * cs);
		vec2 src = centre + dir * src_r / aspect;
		vec4 c = fetch(TEXTURE, src);
		float soft = clamp(softness, 0.0, 1.0);
		float dark = 1.0 - smoothstep(a * (1.0 - 0.3 * soft), a * (1.02 + 0.45 * soft), r);
		COLOR = mix(c, vec4(0.0, 0.0, 0.0, 1.0), dark);
	}
}
