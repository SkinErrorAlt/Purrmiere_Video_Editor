shader_type canvas_item;
render_mode blend_disabled;

uniform int safe = 1;
uniform bool centre = true;
uniform bool thirds = false;
uniform int crop = 0;
uniform float crop_darken : hint_range(0.0, 1.0) = 0.5;
uniform int zones = 0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float width : hint_range(0.5, 8.0) = 1.5;

const vec4 SHORTS[3] = vec4[3](vec4(0.0, 0.0, 1080.0, 150.0), vec4(950.0, 880.0, 130.0, 800.0), vec4(0.0, 1500.0, 940.0, 420.0));
const vec4 TIKTOK[4] = vec4[4](vec4(0.0, 0.0, 1080.0, 160.0), vec4(950.0, 700.0, 130.0, 900.0), vec4(0.0, 1500.0, 940.0, 280.0), vec4(0.0, 1780.0, 1080.0, 140.0));
const vec4 REELS[3] = vec4[3](vec4(0.0, 0.0, 1080.0, 200.0), vec4(960.0, 980.0, 120.0, 760.0), vec4(0.0, 1540.0, 960.0, 380.0));

float box_sd(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

float crop_aspect(int i) {
	if (i == 1) { return 9.0 / 16.0; }
	if (i == 2) { return 1.0; }
	if (i == 3) { return 0.8; }
	if (i == 4) { return 4.0 / 3.0; }
	if (i == 5) { return 16.0 / 9.0; }
	return 2.39;
}

vec4 fitted(vec2 res, float aspect) {
	vec2 s = res.x / res.y > aspect ? vec2(res.y * aspect, res.y) : vec2(res.x, res.x / aspect);
	return vec4((res - s) * 0.5, s);
}

float outline(vec2 px, vec4 r, float half_w) {
	float d = abs(box_sd(px - r.xy - r.zw * 0.5, r.zw * 0.5));
	return clamp(half_w + 0.5 - d, 0.0, 1.0);
}

float inside(vec2 px, vec4 r) {
	return clamp(0.5 - box_sd(px - r.xy - r.zw * 0.5, r.zw * 0.5), 0.0, 1.0);
}

vec4 zone_rect(vec4 z, vec4 area) {
	vec2 k = area.zw / vec2(1080.0, 1920.0);
	return vec4(area.xy + z.xy * k, z.zw * k);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 res = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	vec2 px = UV * res;
	float hw = clamp(width, 0.5, 8.0) * 0.5;
	float line = 0.0;
	float shade = 0.0;
	vec3 zone_rgb = vec3(0.0);
	float zone_a = 0.0;
	if (safe > 0) {
		float a_k = safe == 1 ? 0.93 : 0.9;
		float t_k = safe == 1 ? 0.9 : 0.8;
		line = max(line, outline(px, vec4(res * (1.0 - a_k) * 0.5, res * a_k), hw));
		line = max(line, outline(px, vec4(res * (1.0 - t_k) * 0.5, res * t_k), hw));
	}
	if (centre) {
		vec2 c = res * 0.5;
		float arm = clamp(min(res.x, res.y) * 0.03, 6.0, 60.0);
		vec2 d = abs(px - c);
		float h = clamp(hw + 0.5 - d.y, 0.0, 1.0) * step(d.x, arm);
		float v = clamp(hw + 0.5 - d.x, 0.0, 1.0) * step(d.y, arm);
		line = max(line, max(h, v));
	}
	if (thirds) {
		for (int i = 1; i <= 2; i++) {
			vec2 at = res * float(i) / 3.0;
			line = max(line, clamp(hw + 0.5 - abs(px.x - at.x), 0.0, 1.0));
			line = max(line, clamp(hw + 0.5 - abs(px.y - at.y), 0.0, 1.0));
		}
	}
	if (crop > 0) {
		vec4 r = fitted(res, crop_aspect(crop));
		line = max(line, outline(px, r, hw));
		shade = max(shade, (1.0 - inside(px, r)) * clamp(crop_darken, 0.0, 1.0));
	}
	if (zones > 0) {
		vec4 area = fitted(res, 9.0 / 16.0);
		if (area.z < res.x - 1.0) {
			line = max(line, outline(px, area, hw));
		}
		int n = zones == 2 ? 4 : 3;
		for (int i = 0; i < 4; i++) {
			if (i >= n) {
				break;
			}
			vec4 z = zones == 1 ? SHORTS[min(i, 2)] : (zones == 2 ? TIKTOK[i] : REELS[min(i, 2)]);
			vec4 r = zone_rect(z, area);
			float fill_k = inside(px, r);
			zone_a = max(zone_a, fill_k * 0.28);
			line = max(line, outline(px, r, hw) * 0.8);
		}
	}
	vec3 rgb = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
	vec4 c = vec4(rgb * (1.0 - shade * 0.85) * pic.a, pic.a);
	vec3 zc = mix(vec3(1.0, 0.25, 0.3), colour.rgb, 0.3);
	c = vec4(zc, 1.0) * zone_a + c * (1.0 - zone_a);
	float la = line * colour.a;
	c = vec4(colour.rgb, 1.0) * la + c * (1.0 - la);
	COLOR = c;
}
