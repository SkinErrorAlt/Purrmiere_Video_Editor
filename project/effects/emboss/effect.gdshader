shader_type canvas_item;
render_mode blend_disabled;

uniform float strength : hint_range(0.0, 8.0) = 1.5;
uniform float direction : hint_range(-180.0, 180.0) = 45.0;
uniform float reach : hint_range(0.5, 16.0) = 1.5;
uniform bool keep_colour = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float rad = radians(direction);
	vec2 off = vec2(cos(rad), sin(rad)) * max(reach * max(px_scale, 0.0001), 0.5) / max(tex_size, vec2(1.0));
	vec4 pa = texture(TEXTURE, UV + off);
	vec4 pb = texture(TEXTURE, UV - off);
	vec3 ca = pa.a > 0.0001 ? pa.rgb / pa.a : vec3(0.0);
	vec3 cb = pb.a > 0.0001 ? pb.rgb / pb.a : vec3(0.0);
	vec3 diff = (ca - cb) * strength;
	rgb = keep_colour ? rgb + diff : vec3(0.5) + vec3(dot(diff, vec3(0.2126, 0.7152, 0.0722)));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
