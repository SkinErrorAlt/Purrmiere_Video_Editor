shader_type canvas_item;
render_mode blend_disabled;

uniform float left : hint_range(0.0, 1.0) = 0.3;
uniform float top : hint_range(0.0, 1.0) = 0.3;
uniform float right : hint_range(0.0, 1.0) = 0.3;
uniform float bottom : hint_range(0.0, 1.0) = 0.3;
uniform float roundness : hint_range(0.0, 0.2) = 0.03;
uniform float blur : hint_range(0.0, 60.0) = 14.0;
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform float feather : hint_range(0.0, 0.2) = 0.01;
uniform float border : hint_range(0.0, 20.0) = 3.0;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	float x0 = min(left, 1.0 - right);
	float x1 = max(left, 1.0 - right);
	float y0 = min(top, 1.0 - bottom);
	float y1 = max(top, 1.0 - bottom);
	vec2 ctr = vec2((x0 + x1) * 0.5 * asp, (y0 + y1) * 0.5);
	vec2 half_size = vec2((x1 - x0) * 0.5 * asp, (y1 - y0) * 0.5);
	vec2 p = vec2(UV.x * asp, UV.y) - ctr;
	float d = box(p, half_size, min(roundness, min(half_size.x, half_size.y)));
	float px = 1.0 / sz.y;
	float outside = smoothstep(-px, feather + px, d);
	vec4 blurred = c;
	float r = blur * px_scale;
	if (outside > 0.001 && r > 0.5) {
		vec4 sum = c;
		float wsum = 1.0;
		for (int i = 1; i < 40; i++) {
			float fi = float(i);
			float rr = sqrt(fi / 40.0) * r;
			float a = fi * 2.39996323;
			vec2 o = vec2(cos(a), sin(a)) * rr / sz;
			sum += texture(TEXTURE, clamp(UV + o, vec2(0.0), vec2(1.0)));
			wsum += 1.0;
		}
		blurred = sum / wsum;
	}
	vec4 outc = mix(c, blurred * (1.0 - darken), outside);
	outc.a = mix(c.a, blurred.a, outside);
	float bw = border * px_scale * px;
	if (bw > 0.0) {
		float line = (1.0 - smoothstep(bw * 0.5 - px, bw * 0.5 + px, abs(d - bw * 0.5))) * border_colour.a;
		outc = vec4(outc.rgb * (1.0 - line) + border_colour.rgb * line, outc.a + line * (1.0 - outc.a));
	}
	COLOR = outc;
}
