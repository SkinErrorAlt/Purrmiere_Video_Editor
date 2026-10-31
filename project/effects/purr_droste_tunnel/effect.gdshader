shader_type canvas_item;
render_mode blend_disabled;

uniform float ratio : hint_range(0.15, 0.9) = 0.5;
uniform float speed : hint_range(-2.0, 2.0) = 0.3;
uniform float twist : hint_range(-3.0, 3.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float frame : hint_range(0.0, 20.0) = 3.0;
uniform vec4 frame_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

void fragment() {
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float ls = log(ratio);
	float phase = fract(clip_time * speed);
	vec2 qz = q * pow(ratio, phase);
	float b = max(abs(qz.x) / asp, abs(qz.y)) * 2.0;
	b = max(b, 0.000001);
	float k = max(floor(log(b) / ls), 0.0);
	vec2 ql = qz / pow(ratio, k);
	ql = rot(twist * log(b)) * ql;
	vec2 suv = clamp(centre + ql / vec2(asp, 1.0), vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, suv);
	float bl = max(abs(ql.x) / asp, abs(ql.y)) * 2.0;
	float px = px_scale / max(tex_size.y, 1.0) * pow(ratio, -k) * pow(ratio, phase);
	float fl = smoothstep(frame * px + px, frame * px, 1.0 - bl) * step(0.01, frame) * step(0.5, k);
	COLOR = mix(c, vec4(frame_colour.rgb, 1.0) * frame_colour.a, fl * frame_colour.a);
}
