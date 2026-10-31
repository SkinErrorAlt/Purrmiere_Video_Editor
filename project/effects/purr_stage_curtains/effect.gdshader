shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec4 fabric : source_color = vec4(0.62, 0.04, 0.08, 1.0);
uniform vec4 trim : source_color = vec4(0.95, 0.75, 0.3, 1.0);
uniform int folds : hint_range(3, 30) = 10;
uniform float sway : hint_range(0.0, 1.0) = 0.4;
uniform bool valance = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	float x = UV.x < 0.5 ? UV.x : 1.0 - UV.x;
	float side = UV.x < 0.5 ? 0.0 : 1.0;
	float reach = pg * 0.505 + sway * 0.03 * sin(UV.y * 3.0 + pg * 6.0 + side) * pg * (1.0 - pg) * 4.0;
	float hem = reach;
	float u = x / max(reach, 0.0001);
	float fv = cos(u * float(folds) * 3.14159) * 0.5 + 0.5;
	float px = px_scale / max(tex_size.x, 1.0);
	float cur = smoothstep(px, -px, x - hem) * step(0.0001, pg);
	vec3 cc = fabric.rgb * (0.45 + 0.75 * fv) * (0.85 + 0.15 * (1.0 - UV.y));
	float edge = smoothstep(px * 14.0, px * 6.0, hem - x) * cur;
	cc = mix(cc, trim.rgb * (0.7 + 0.3 * fv), edge);
	vec4 o = mix(c, vec4(cc, 1.0), cur);
	if (valance) {
		float vh = 0.12 + 0.025 * cos(UV.x * 6.28318 * 4.0);
		float vv = smoothstep(px * 2.0, -px * 2.0, UV.y - vh);
		vec3 vc = fabric.rgb * (0.6 + 0.4 * (0.5 + 0.5 * cos(UV.x * 80.0)));
		vc = mix(vc, trim.rgb, smoothstep(vh - 0.02, vh - 0.01, UV.y));
		o = mix(o, vec4(vc, 1.0), vv);
	}
	COLOR = pg <= 0.0 && !valance ? c : o;
}
