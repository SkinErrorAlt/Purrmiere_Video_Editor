shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float amount : hint_range(0.0,1.0) = 0.55;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float peak = sin(e*TR_PI);
	float blk = floor(uv.y*22.0);
	float jx = (tr_hash(vec2(blk, floor(e*24.0)))-0.5)*peak*amount*0.3;
	vec2 z = (uv-vec2(0.5))/(1.0+peak*amount*0.45)+vec2(0.5);
	vec2 g = z + vec2(jx,0.0);
	float m = smoothstep(0.42,0.58,e);
	float sp = peak*amount*0.02;
	float r = mix(from_clamped(g+vec2(sp,0.0)), to_clamped(g+vec2(sp,0.0)), m).r;
	float gg = mix(from_clamped(g), to_clamped(g), m).g;
	float b = mix(from_clamped(g-vec2(sp,0.0)), to_clamped(g-vec2(sp,0.0)), m).b;
	return vec4(r,gg,b,1.0);
}
void fragment(){ COLOR = transition(UV); }
