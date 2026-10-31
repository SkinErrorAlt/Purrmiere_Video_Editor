shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int axis = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float keep_edges : hint_range(0.01, 0.4) = 0.1;
uniform float block_size : hint_range(2.0, 32.0) = 8.0;
uniform float offset_x : hint_range(0.0, 32.0) = 0.0;
uniform float offset_y : hint_range(0.0, 32.0) = 0.0;
uniform bool show_grid = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec4 at(sampler2D tex, vec2 uv) {
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 dir = axis == 0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec2 step_uv = dir * ps / size;
	float pos = (axis == 0 ? UV.x * size.x : UV.y * size.y) / ps;
	float off = axis == 0 ? offset_x : offset_y;
	float bsz = clamp(block_size, 2.0, 32.0);
	float s = pos - off;
	float b = floor(s / bsz);
	float t = s - b * bsz;
	bool q_side = t < bsz * 0.5;
	float dist = q_side ? t : bsz - t;
	float k = floor(dist);
	float reach = clamp(1.0 + 2.0 * clamp(strength, 0.0, 1.0), 1.0, 3.0) * max(bsz / 8.0, 1.0);
	reach = min(reach, bsz * 0.5);
	vec4 c = texture(TEXTURE, UV);
	vec4 outc = c;
	if (strength > 0.0 && k < reach) {
		float boundary = (q_side ? b : b + 1.0) * bsz + off;
		float along = boundary * ps;
		vec2 buv = axis == 0 ? vec2(along / size.x, UV.y) : vec2(UV.x, along / size.y);
		vec4 p0 = at(TEXTURE, buv - step_uv * 0.5);
		vec4 p1 = at(TEXTURE, buv - step_uv * 1.5);
		vec4 q0 = at(TEXTURE, buv + step_uv * 0.5);
		vec4 q1 = at(TEXTURE, buv + step_uv * 1.5);
		vec4 slope = 0.5 * ((p0 - p1) + (q1 - q0));
		vec4 d = (q0 - p0) - slope;
		float dl = abs(dot(d.rgb, LUMA));
		float fp = abs(dot((p0 - p1).rgb, LUMA));
		float fq = abs(dot((q1 - q0).rgb, LUMA));
		float beta = keep_edges * 0.5;
		float gate = (1.0 - smoothstep(keep_edges * 0.7, keep_edges, dl)) * (1.0 - smoothstep(beta * 0.7, beta, max(fp, fq)));
		float w = max(reach - k - 0.5, 0.0) / (2.0 * reach);
		vec4 fix_v = d * w * gate * clamp(strength * 1.5, 0.0, 1.0);
		outc = q_side ? c - fix_v : c + fix_v;
	}
	if (show_grid && axis == 1) {
		vec2 sp = UV * size / ps - vec2(offset_x, offset_y);
		vec2 g = abs(sp - bsz * floor(sp / bsz + 0.5));
		float line = 1.0 - smoothstep(0.55, 1.05, min(g.x, g.y) / ps);
		outc = mix(outc, vec4(1.0, 0.2, 0.2, 1.0) * max(outc.a, 0.6), line * 0.6);
	}
	outc.rgb = clamp(outc.rgb, vec3(0.0), vec3(outc.a));
	COLOR = outc;
}
