shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.05, 5.0) = 0.7;
uniform float size : hint_range(0.05, 2.0) = 0.9;
uniform float ring_width : hint_range(2.0, 400.0) = 90.0;
uniform float strength : hint_range(-200.0, 200.0) = 60.0;
uniform float colour_split : hint_range(0.0, 1.0) = 0.5;
uniform float rim : hint_range(0.0, 1.0) = 0.4;
uniform float repeat_every : hint_range(0.0, 10.0) = 0.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec4 fetch(sampler2D tex, vec2 pix, vec2 sz) {
	return texture(tex, clamp(pix / sz, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dt = clip_time - starts_at;
	if (repeat_every > 0.001 && dt >= 0.0) {
		dt = mod(dt, repeat_every);
	}
	float dur = max(duration, 0.01);
	float q = dt / dur;
	if (q < 0.0 || q >= 1.0) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		vec2 cpx = centre * sz;
		vec2 pix = UV * sz;
		vec2 d = pix - cpx;
		float r = length(d);
		vec2 dir = r > 0.001 ? d / r : vec2(0.0);
		float grow = 1.0 - pow(1.0 - q, 2.2);
		float radius = grow * max(size, 0.0) * length(sz);
		float w = max(ring_width * ps, 1.0) * (0.6 + 0.6 * grow);
		float x = (r - radius) / w;
		float fade = pow(1.0 - q, 1.4) * smoothstep(0.0, 0.08, q);
		float shape = -x * exp(-x * x * 2.5) * 1.65;
		float push = strength * ps * fade * shape;
		float split = clamp(colour_split, 0.0, 1.0) * 0.45;
		vec4 cg = fetch(TEXTURE, pix - dir * push, sz);
		vec4 cr = fetch(TEXTURE, pix - dir * push * (1.0 + split), sz);
		vec4 cb = fetch(TEXTURE, pix - dir * push * (1.0 - split), sz);
		float a = max(cg.a, max(cr.a, cb.a));
		vec3 rgb = vec3(cr.a > 0.0001 ? cr.r / cr.a : 0.0, cg.a > 0.0001 ? cg.g / cg.a : 0.0, cb.a > 0.0001 ? cb.b / cb.a : 0.0);
		float ring = exp(-x * x * 6.0) * fade * clamp(rim, 0.0, 1.0);
		rgb = rgb + (1.0 - rgb) * ring * 0.8;
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
