shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 sun = vec2(0.78, 0.06);
uniform float span = 1.0;

float fetch(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 1.0;
	}
	return texture(tex, uv).r;
}

void fragment() {
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	vec2 d = UV - sun;
	float dist = length(d * vec2(aspect, 1.0));
	float reach = min(1.0, 0.75 / max(dist, 0.0001)) * span;
	float sum = 0.0;
	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0;
		sum += fetch(TEXTURE, sun + d * (1.0 - reach * t));
	}
	COLOR = vec4(vec3(sum / 12.0), 1.0);
}
