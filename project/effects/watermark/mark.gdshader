shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D picture : filter_linear, repeat_disable, hint_default_transparent;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform int placement = 3;
uniform float size : hint_range(0.02, 0.5) = 0.09;
uniform float margin : hint_range(0.0, 0.2) = 0.045;
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
uniform int show = 0;
uniform float every : hint_range(5.0, 600.0) = 60.0;
uniform float shows_for : hint_range(1.0, 60.0) = 8.0;
uniform float fade : hint_range(0.0, 3.0) = 0.6;
uniform float tile_angle : hint_range(-60.0, 60.0) = -30.0;
uniform float tile_gap : hint_range(1.2, 6.0) = 2.5;

float box_sd(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec4 badge(vec2 uv, float aa) {
	vec2 p = uv - 0.5;
	float body = box_sd(p, vec2(0.47, 0.34), 0.12);
	vec2 t = p - vec2(0.15, 0.0);
	float tri = max(max(-0.25 - t.x, dot(t, vec2(0.4886, 0.8725))), dot(t, vec2(0.4886, -0.8725)));
	float cov = clamp(0.5 - body / aa, 0.0, 1.0);
	float hole = clamp(0.5 - tri / aa, 0.0, 1.0);
	return vec4(vec3(1.0), 1.0) * cov * (1.0 - hole);
}

vec4 logo(vec2 uv, bool has_pic, float aa) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	if (has_pic) {
		vec4 t = texture(picture, uv);
		return vec4(t.rgb * t.a, t.a);
	}
	return badge(uv, aa);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 k = vec2(asp, 1.0);
	vec2 q = UV * k;
	vec2 ts = vec2(textureSize(picture, 0));
	bool has_pic = ts.x > 4.5 || ts.y > 4.5;
	float la = has_pic ? ts.x / max(ts.y, 1.0) : 1.0;
	float h = clamp(size, 0.02, 0.5);
	vec2 box = vec2(h * la, h);
	if (box.x > asp * 0.9) {
		box *= asp * 0.9 / box.x;
	}
	float vis = 1.0;
	if (show == 1) {
		float per = max(every, 1.0);
		float on = min(max(shows_for, 0.5), per);
		float tt = mod(max(clip_time, 0.0), per);
		float f = max(fade, 0.0001);
		vis = clamp(tt / f, 0.0, 1.0) * clamp((on - tt) / f, 0.0, 1.0);
	}
	vec4 m = vec4(0.0);
	if (placement == 5) {
		float a = radians(tile_angle);
		vec2 r = vec2(cos(a) * q.x + sin(a) * q.y, -sin(a) * q.x + cos(a) * q.y);
		vec2 cell = box * clamp(tile_gap, 1.2, 6.0);
		vec2 g = r / cell;
		if (mod(floor(g.y), 2.0) > 0.5) {
			g.x += 0.5;
		}
		vec2 local = (fract(g) - 0.5) * cell / box + 0.5;
		float aa = max(length(fwidth(local)) * 0.7071, 0.0001);
		m = logo(local, has_pic, aa);
	} else {
		float mg = clamp(margin, 0.0, 0.2);
		vec2 hb = box * 0.5;
		vec2 c = vec2(asp * 0.5, 0.5);
		if (placement == 0) { c = vec2(mg + hb.x, mg + hb.y); }
		else if (placement == 1) { c = vec2(asp - mg - hb.x, mg + hb.y); }
		else if (placement == 2) { c = vec2(mg + hb.x, 1.0 - mg - hb.y); }
		else if (placement == 3) { c = vec2(asp - mg - hb.x, 1.0 - mg - hb.y); }
		vec2 local = (q - c) / box + 0.5;
		float aa = max(length(fwidth(local)) * 0.7071, 0.0001);
		m = logo(local, has_pic, aa);
	}
	float a = clamp(opacity, 0.0, 1.0) * vis;
	m *= a;
	COLOR = m + pic * (1.0 - m.a);
}
