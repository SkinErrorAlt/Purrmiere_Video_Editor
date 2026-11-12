shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float sheet_width : hint_range(0.05, 4.0) = 1.3;
uniform float sheet_height : hint_range(0.05, 2.0) = 0.8;
uniform float focal : hint_range(-4.0, 4.0) = 1.0;
uniform float distance : hint_range(0.0, 4.0) = 0.42;
uniform float pitch : hint_range(1.0, 60.0) = 7.0;
uniform float grooves : hint_range(0.0, 1.0) = 0.5;
uniform float glints : hint_range(0.0, 1.0) = 0.45;
uniform float light_angle : hint_range(-180.0, 180.0) = -50.0;
uniform float dispersion : hint_range(0.0, 1.0) = 0.4;
uniform vec4 tint : source_color = vec4(0.97, 0.98, 1.0, 1.0);

vec2 mirror_uv(vec2 uv) {
	vec2 t = mod(uv, 2.0);
	return mix(t, 2.0 - t, step(1.0, t));
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 asp = vec2(aspect, 1.0);
	vec2 p = (UV - centre) * asp;
	vec2 hs = vec2(sheet_width, sheet_height) * 0.5;
	float pxh = 1.0 / tex_size.y;
	vec2 ed = hs - abs(p);
	float inside = smoothstep(0.0, 1.5 * pxh, min(ed.x, ed.y));
	vec4 back = texture(TEXTURE, UV);
	if (inside <= 0.0) {
		COLOR = back;
	} else {
		float r = length(p);
		vec2 dir = r > 1e-6 ? p / r : vec2(1.0, 0.0);
		float w = max(pitch * px_scale, 0.5) * pxh;
		float zone = floor(r / w);
		float u = r / w - zone;
		float rk = (zone + 0.5) * w;
		float f = abs(focal) < 0.02 ? (focal < 0.0 ? -0.02 : 0.02) : focal;
		vec3 nfac = 1.0 + vec3(-0.012, 0.0, 0.02) * dispersion * 1.8;
		vec4 col = vec4(0.0);
		vec3 rgb;
		for (int c = 0; c < 3; c++) {
			float fc = f / nfac[c];
			float rs = r - distance * rk / fc;
			vec2 q = dir * rs;
			vec2 uv = centre + q / asp;
			vec4 s = texture(TEXTURE, mirror_uv(uv));
			rgb[c] = s[c];
			col.a += s.a / 3.0;
		}
		float slope = rk / abs(f);
		float riser = clamp(slope * 0.18 + 0.02, 0.0, 0.5);
		float edge_px = 1.0 / max(w * tex_size.y, 1.0);
		float line = smoothstep(1.0 - riser - edge_px, 1.0 - riser, u) * (1.0 - smoothstep(1.0 - edge_px, 1.0, u));
		vec2 L = vec2(cos(radians(light_angle)), sin(radians(light_angle)));
		float facing = dot(dir, L);
		float sheen = pow(max(facing, 0.0), 6.0) * smoothstep(0.0, 0.6, slope);
		float glint = line * sheen * glints * 1.6;
		float shade = 1.0 - line * grooves * (0.35 + 0.4 * max(-facing, 0.0));
		vec3 c3 = rgb * tint.rgb * shade + vec3(glint) * col.a;
		float haze = 0.03 * glints;
		c3 = c3 * (1.0 - haze) + haze * col.a;
		vec2 bd = smoothstep(vec2(3.0 * pxh), vec2(0.0), ed);
		float rim = max(bd.x, bd.y);
		c3 = mix(c3, vec3(min(1.0, dot(c3, vec3(0.33)) + 0.35)) * col.a, rim * 0.6);
		vec4 sheet = vec4(min(c3, vec3(col.a)), col.a);
		COLOR = mix(back, sheet, inside);
	}
}
