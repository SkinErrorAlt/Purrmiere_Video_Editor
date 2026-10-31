shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 film : source_color = vec4(0.07, 0.06, 0.05, 1.0);
uniform float band : hint_range(0.0, 0.3) = 0.11;
uniform float hole : hint_range(0.2, 0.9) = 0.55;
uniform int holes : hint_range(4, 60) = 18;
uniform float roll : hint_range(-3.0, 3.0) = 0.0;
uniform float frame_line : hint_range(0.0, 0.05) = 0.008;
uniform bool vertical = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

void fragment() {
	vec2 uv = vertical ? UV.yx : UV;
	vec2 ts = vertical ? tex_size.yx : tex_size;
	float asp = ts.x / max(ts.y, 1.0);
	float b = band;
	float inner = 1.0 - 2.0 * b;
	float x = uv.x + clip_time * roll * 0.25;
	vec2 su = vec2(fract(x), (uv.y - b) / max(inner, 0.001));
	vec2 suv = vertical ? su.yx : su;
	vec4 c = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
	float inpic = step(b, uv.y) * step(uv.y, 1.0 - b);
	float fl = smoothstep(frame_line, frame_line * 0.5, min(fract(x), 1.0 - fract(x)) / asp) * step(0.0001, frame_line);
	float n = float(holes);
	vec2 hp = vec2(fract(x * n) - 0.5, 0.0);
	float yb = uv.y < 0.5 ? uv.y : 1.0 - uv.y;
	hp.y = (yb - b * 0.5) / max(b, 0.0001);
	hp.x *= asp / n / max(b, 0.0001);
	vec2 hs = vec2(0.5 / n * asp / max(b, 0.0001) * hole * 0.6, hole * 0.32);
	vec2 q = abs(hp) - hs + 0.08;
	float hd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.08;
	float holev = smoothstep(0.02, -0.02, hd) * (1.0 - inpic);
	vec4 pic = c * inpic;
	pic = mix(pic, vec4(film.rgb, 1.0), fl * inpic);
	vec4 edge = vec4(film.rgb, 1.0) * (1.0 - inpic) * (1.0 - holev);
	COLOR = pic + edge;
}
