shader_type canvas_item;
render_mode blend_disabled;

uniform float across : hint_range(4.0, 160.0) = 44.0;
uniform float ball : hint_range(0.3, 1.4) = 1.0;
uniform float spin : hint_range(-1.0, 1.0) = 0.0;
uniform float roll_rate : hint_range(-2.0, 2.0) = 0.0;
uniform float shade : hint_range(0.0, 1.0) = 0.8;
uniform float shine : hint_range(0.0, 2.0) = 0.8;
uniform vec4 backdrop : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float clip_time = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0) {
		COLOR = base;
	} else {
		float ar = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
		float nx = max(across, 4.0);
		float ny = max(floor(nx / max(ar, 0.0001)), 1.0);
		vec2 grid = vec2(nx, ny);
		vec2 cell = floor(UV * grid);
		vec2 within = fract(UV * grid) - 0.5;
		vec2 q = within / max(ball * 0.5, 0.0001);
		float d2 = dot(q, q);
		if (d2 > 1.0) {
			COLOR = mix(base, backdrop, strength);
		} else {
			float z = sqrt(max(1.0 - d2, 0.0));
			vec3 n = normalize(vec3(q, z));
			float roll = spin + roll_rate * clip_time;
			vec2 pick = (cell + 0.5) / grid + vec2(n.x, n.y) * roll * 0.5 / grid;
			vec3 c = texture(TEXTURE, clamp(pick, vec2(0.0), vec2(1.0))).rgb;
			vec3 light = normalize(vec3(-0.45, -0.55, 0.7));
			float lam = clamp(dot(n, light), 0.0, 1.0);
			float spec = pow(lam, 24.0);
			vec3 lit = c * mix(1.0, 0.22 + 1.15 * lam, shade) + vec3(spec * shine);
			float edge = 1.0 - smoothstep(0.86, 1.0, sqrt(d2));
			vec3 shown = mix(backdrop.rgb, lit, edge);
			COLOR = mix(base, vec4(shown, 1.0), strength);
		}
	}
}
