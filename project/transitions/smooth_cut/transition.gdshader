shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float blur_amt : hint_range(6.0,120.0) = 48.0;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float b = sin(e*TR_PI)*blur_amt;
	float m = smoothstep(0.4,0.6,e);
	return mix(from_blur(uv,b), to_blur(uv,b), m);
}
void fragment(){ COLOR = transition(UV); }
