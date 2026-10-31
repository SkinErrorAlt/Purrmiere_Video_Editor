shader_type canvas_item;
render_mode blend_disabled;

uniform float spin : hint_range(-360.0, 360.0) = 0.0;
uniform float radius : hint_range(0.05, 1.0) = 0.45;
uniform float wrap : hint_range(0.1, 1.0) = 0.5;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform bool show_back = true;
uniform bool horizontal = false;

void fragment() {
	vec2 q = horizontal ? UV.yx : UV;
	float x = (q.x - 0.5) / max(radius, 0.001);
	vec4 o = vec4(0.0);
	if (abs(x) < 1.0) {
		float s = asin(x);
		float sp = radians(spin);
		float span = 6.2831853 * wrap;
		float uf = 0.5 + (s + sp) / span;
		float ub = 0.5 + (3.14159265 - s + sp) / span;
		uf = uf - floor(uf / (6.2831853 / span)) * (6.2831853 / span);
		ub = ub - floor(ub / (6.2831853 / span)) * (6.2831853 / span);
		float lit = mix(1.0, sqrt(max(1.0 - x * x, 0.0)), shading);
		float edge = smoothstep(1.0, 0.98, abs(x));
		if (uf >= 0.0 && uf <= 1.0) {
			vec2 uv = vec2(uf, q.y);
			vec4 t = texture(TEXTURE, horizontal ? uv.yx : uv);
			o = vec4(t.rgb * lit, t.a) * edge;
		}
		if (show_back && o.a < 0.999 && ub >= 0.0 && ub <= 1.0) {
			vec2 uv = vec2(ub, q.y);
			vec4 t = texture(TEXTURE, horizontal ? uv.yx : uv);
			vec4 bk = vec4(t.rgb * lit * 0.5, t.a) * edge;
			o = o + bk * (1.0 - o.a);
		}
	}
	COLOR = o;
}
