shader_type canvas_item;
render_mode blend_disabled;

uniform float angle : hint_range(-90.0, 90.0) = -18.0;
uniform vec2 position = vec2(0.5, 0.5);
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float draw_time : hint_range(0.0, 1.0) = 0.12;
uniform float slide_time : hint_range(0.02, 3.0) = 0.45;
uniform float slide : hint_range(0.0, 300.0) = 60.0;
uniform float gap : hint_range(0.0, 100.0) = 4.0;
uniform vec4 glow_colour : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 1.0;
uniform float glow_width : hint_range(0.0, 60.0) = 14.0;
uniform float edge_light : hint_range(0.0, 1.0) = 0.35;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec4 fetch(sampler2D tex, vec2 pix, vec2 sz) {
	return texture(tex, clamp(pix / sz, vec2(0.0), vec2(1.0)));
}

void fragment() {
	float dt = clip_time - starts_at;
	if (dt < 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		vec2 pix = UV * sz;
		vec2 p0 = position * sz;
		float ang = radians(angle);
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 nrm = vec2(-dir.y, dir.x);
		float dtime = max(draw_time, 0.0);
		float drawn = dtime > 0.001 ? clamp(dt / dtime, 0.0, 1.0) : 1.0;
		float sl = clamp((dt - dtime) / max(slide_time, 0.001), 0.0, 1.0);
		float m = 1.0 - (1.0 - sl) * (1.0 - sl) * (1.0 - sl);
		vec2 off_a = (dir * max(slide, 0.0) + nrm * max(gap, 0.0)) * ps * 0.5 * m;
		vec2 pa = pix - off_a;
		vec2 pb = pix + off_a;
		float sa = dot(pa - p0, nrm);
		float sb = dot(pb - p0, nrm);
		float cov_a = smoothstep(-0.5, 0.5, sa);
		float cov_b = smoothstep(-0.5, 0.5, -sb);
		vec4 ca = fetch(TEXTURE, pa, sz);
		vec4 cb = fetch(TEXTURE, pb, sz);
		float lit = clamp(edge_light, 0.0, 1.0) * drawn;
		float edge_a = exp(-max(sa, 0.0) / (1.6 * ps)) * lit;
		float edge_b = exp(-max(-sb, 0.0) / (1.6 * ps)) * lit;
		ca.rgb = ca.rgb + (vec3(ca.a) - ca.rgb) * edge_a * 0.8;
		cb.rgb = cb.rgb + (vec3(cb.a) - cb.rgb) * edge_b * 0.8;
		vec4 col = ca * cov_a + cb * cov_b * (1.0 - cov_a);
		float s = dot(pix - p0, nrm);
		float u = dot(pix - p0, dir);
		float half_len = length(sz);
		float head = mix(-half_len, half_len, 1.0 - (1.0 - drawn) * (1.0 - drawn));
		float behind = head - u;
		float w = max(glow_width, 0.0) * ps;
		float fade = 1.0 - smoothstep(dtime, dtime + 0.35, dt);
		float streak = 0.0;
		if (behind >= 0.0 && w > 0.0) {
			float tail = exp(-behind / (half_len * 0.7));
			float core = exp(-(s * s) / max(w * w * 0.06, 0.25));
			float halo = exp(-abs(s) / w) * 0.55;
			float tip = smoothstep(0.0, w * 3.0, behind);
			streak = (core + halo) * tail * tip * fade * clamp(glow, 0.0, 1.0) * glow_colour.a;
		}
		streak = clamp(streak, 0.0, 1.0);
		vec3 rgb_pm = glow_colour.rgb * streak + col.rgb * (1.0 - streak);
		float a = streak + col.a * (1.0 - streak);
		COLOR = vec4(clamp(rgb_pm, vec3(0.0), vec3(a)), a);
	}
}
