shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius : hint_range(0.1, 1.0) = 0.42;
uniform float bulge : hint_range(0.0, 3.0) = 1.3;
uniform float fringe : hint_range(0.0, 1.0) = 0.4;
uniform float ring : hint_range(0.0, 60.0) = 16.0;
uniform vec4 brass : source_color = vec4(0.75, 0.58, 0.26, 1.0);
uniform vec4 surround : source_color = vec4(0.03, 0.03, 0.035, 1.0);
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float r = length(q);
	float rn = r / radius;
	float k = pow(max(rn, 0.0001), bulge * 0.6);
	vec2 src = q * k * 0.9;
	float fr = fringe * 0.02 * rn * rn;
	vec2 base = centre + src / vec2(asp, 1.0);
	vec2 dirv = r > 0.0001 ? q / r : vec2(0.0);
	vec4 cr = texture(TEXTURE, base + dirv * fr);
	vec4 cg = texture(TEXTURE, base);
	vec4 cb = texture(TEXTURE, base - dirv * fr);
	vec4 c = vec4(cr.r, cg.g, cb.b, cg.a);
	c.rgb *= 1.0 - smoothstep(0.6, 1.0, rn) * 0.6;
	float px = px_scale / max(tex_size.y, 1.0);
	float inside = smoothstep(px, -px, r - radius);
	float rg = smoothstep(px, -px, abs(r - radius - ring * px * 0.5) - ring * px * 0.5) * step(0.01, ring);
	float an = atan(q.y, q.x);
	vec3 br = brass.rgb * (0.65 + 0.45 * pow(0.5 + 0.5 * cos(an + 2.3), 2.0)) * (0.9 + 0.2 * smoothstep(0.0, ring * px, r - radius));
	vec4 sur = vec4(surround.rgb * (0.8 + 0.4 * (1.0 - smoothstep(radius, radius * 2.5, r))), 1.0);
	vec4 o = mix(sur, c + sur * (1.0 - c.a), inside);
	o = mix(o, vec4(br, 1.0), rg);
	COLOR = o;
}
