shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float intensity : hint_range(0.0,1.5) = 0.85;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float peak = sin(e*TR_PI);
	float line = floor(uv.y*180.0);
	float jit = (tr_hash(vec2(line, floor(e*40.0)))-0.5) * intensity * 0.08 * peak;
	float bar = smoothstep(0.42,0.52, tr_fbm(vec2(uv.y*8.0 - e*22.0, 1.0)));
	vec2 guv = uv + vec2(jit + bar*0.03, 0.0);
	float m = smoothstep(0.45,0.55,e);
	float sp = intensity*0.012*peak;
	float r = mix(from_clamped(guv+vec2(sp,0.0)), to_clamped(guv+vec2(sp,0.0)), m).r;
	float gg = mix(from_clamped(guv), to_clamped(guv), m).g;
	float b = mix(from_clamped(guv-vec2(sp,0.0)), to_clamped(guv-vec2(sp,0.0)), m).b;
	vec3 c = vec3(r,gg,b);
	c *= 0.86 + 0.14*sin(uv.y*700.0);
	c += bar * 0.25 * peak;
	return vec4(clamp(c,0.0,1.0), 1.0);
}
void fragment(){ COLOR = transition(UV); }
