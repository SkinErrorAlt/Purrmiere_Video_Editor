shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float amount : hint_range(0.0, 1.0) = 0.7;
uniform float chroma_bleed : hint_range(0.0, 1.0) = 0.7;
uniform float wobble : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform float head_switch : hint_range(0.0, 1.0) = 0.6;
uniform float desaturate : hint_range(0.0, 1.0) = 0.25;
uniform float softness : hint_range(0.0, 4.0) = 1.0;
uniform float speed : hint_range(0.0, 8.0) = 1.0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float t = time * speed;
	float k = clamp(amount, 0.0, 1.0);
	float row = floor(UV.y * size.y);
	float jitter = (hash12(vec2(row, floor(t * 30.0))) - 0.5) * wobble * 6.0 * max(px_scale, 0.0001) / size.x;
	float band = smoothstep(0.02, 0.0, abs(fract(UV.y + t * 0.13) - 0.5));
	jitter += band * wobble * 12.0 * max(px_scale, 0.0001) / size.x;
	float bottom = smoothstep(0.035, 0.0, 1.0 - UV.y);
	jitter += bottom * head_switch * (hash12(vec2(row, floor(t * 24.0))) - 0.5) * 60.0 * max(px_scale, 0.0001) / size.x;
	vec2 uv = clamp(UV + vec2(jitter * k, 0.0), vec2(0.0), vec2(1.0));
	float soft = softness * max(px_scale, 0.0001) / size.x;
	vec4 c = texture(TEXTURE, uv);
	vec4 cl = texture(TEXTURE, clamp(uv - vec2(soft, 0.0), vec2(0.0), vec2(1.0)));
	vec4 cr = texture(TEXTURE, clamp(uv + vec2(soft, 0.0), vec2(0.0), vec2(1.0)));
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 rl = cl.a > 0.0001 ? cl.rgb / cl.a : vec3(0.0);
	vec3 rr = cr.a > 0.0001 ? cr.rgb / cr.a : vec3(0.0);
	vec3 blurred = (rl + rgb * 2.0 + rr) * 0.25;
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	float bleed_px = chroma_bleed * 5.0 * max(px_scale, 0.0001) / size.x;
	vec4 cb = texture(TEXTURE, clamp(uv - vec2(bleed_px, 0.0), vec2(0.0), vec2(1.0)));
	vec3 rb = cb.a > 0.0001 ? cb.rgb / cb.a : vec3(0.0);
	vec3 chroma = rb - vec3(dot(rb, vec3(0.299, 0.587, 0.114)));
	vec3 out_rgb = vec3(dot(blurred, vec3(0.299, 0.587, 0.114))) + mix(rgb - vec3(luma), chroma, chroma_bleed);
	out_rgb = mix(out_rgb, vec3(dot(out_rgb, vec3(0.299, 0.587, 0.114))), desaturate);
	float n = hash12(UV * size * 0.5 + floor(t * 30.0) * 7.3) - 0.5;
	out_rgb += n * grain * 0.35;
	out_rgb += bottom * head_switch * (hash12(vec2(row * 3.0, floor(t * 24.0))) - 0.35) * 0.8;
	rgb = mix(rgb, out_rgb, k);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
