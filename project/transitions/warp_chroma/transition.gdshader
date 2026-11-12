shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float amount : hint_range(0.0,0.6) = 0.3;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float peak = sin(e*TR_PI);
	vec2 c = uv - vec2(0.5);
	vec2 wuv = uv - c*peak*amount;
	float m = smoothstep(0.4,0.6,e);
	vec2 dir = normalize(c + vec2(0.0001));
	float sp = peak*amount*0.07;
	float r = mix(from_clamped(wuv + dir*sp), to_clamped(wuv + dir*sp), m).r;
	float gg = mix(from_clamped(wuv), to_clamped(wuv), m).g;
	float b = mix(from_clamped(wuv - dir*sp), to_clamped(wuv - dir*sp), m).b;
	return vec4(r,gg,b,1.0);
}
void fragment(){ COLOR = transition(UV); }
