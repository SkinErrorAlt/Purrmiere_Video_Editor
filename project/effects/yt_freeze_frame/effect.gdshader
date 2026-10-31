shader_type canvas_item;
render_mode blend_disabled;

uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.8;
uniform float drain : hint_range(0.0, 1.0) = 0.6;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.25;
uniform float frame : hint_range(0.0, 120.0) = 18.0;
uniform vec4 frame_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline : hint_range(0.0, 20.0) = 3.0;
uniform float tilt : hint_range(-20.0, 20.0) = -3.0;
uniform float push : hint_range(0.0, 30.0) = 6.0;
uniform float settle : hint_range(0.0, 2.0) = 0.35;
uniform vec4 background : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform float clip_time;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

void fragment() {
	float t = clip_time - starts_at;
	if (t < 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		float e = settle > 0.001 ? clamp(t / settle, 0.0, 1.0) : 1.0;
		e = 1.0 - pow(1.0 - e, 3.0);
		float ang = radians(tilt) * e;
		float s = 1.0 - 0.12 * e + push * 0.01 * e * 0.5;
		vec2 p = UV - 0.5;
		p.x *= asp;
		p = vec2(cos(ang) * p.x + sin(ang) * p.y, -sin(ang) * p.x + cos(ang) * p.y) / max(s, 0.01);
		p.x /= asp;
		vec2 uv = p + 0.5;
		vec2 fp = frame * px_scale * e / sz;
		vec2 op = outline * px_scale * e / sz;
		vec2 lo = -fp;
		vec2 hi = vec2(1.0) + fp;
		bool in_pic = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
		bool in_frame = uv.x >= lo.x && uv.y >= lo.y && uv.x <= hi.x && uv.y <= hi.y;
		bool in_line = uv.x >= lo.x - op.x && uv.y >= lo.y - op.y && uv.x <= hi.x + op.x && uv.y <= hi.y + op.y;
		vec4 outc = vec4(background.rgb * background.a, background.a);
		if (in_pic) {
			vec4 c = texture(TEXTURE, uv);
			vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
			float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
			rgb = mix(rgb, vec3(y), drain * e);
			rgb = mix(rgb, rgb * tint.rgb * 1.15, tint_amount * e);
			float fl = flash * clamp(1.0 - t / 0.25, 0.0, 1.0);
			rgb = mix(rgb, vec3(1.0), fl);
			vec3 back = background.rgb * background.a;
			outc = vec4(clamp(rgb, 0.0, 1.0) * c.a + back * (1.0 - c.a), c.a + background.a * (1.0 - c.a));
		} else if (in_frame) {
			outc = vec4(frame_colour.rgb * frame_colour.a, frame_colour.a);
		} else if (in_line) {
			outc = vec4(0.0, 0.0, 0.0, 1.0);
		}
		COLOR = outc;
	}
}
