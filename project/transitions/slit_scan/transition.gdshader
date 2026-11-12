shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int dir = 0;
uniform float spread : hint_range(0.0,1.0) = 0.6;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float coord = uv.x;
	if(dir==1){ coord = 1.0-uv.x; } else if(dir==2){ coord = uv.y; } else if(dir==3){ coord = 1.0-uv.y; }
	float pe = clamp(e*(1.0+spread) - coord*spread, 0.0, 1.0);
	float stretch = (1.0 - abs(pe-0.5)*2.0) * spread * 0.12;
	vec2 sdir = (dir<2)? vec2(1.0,0.0) : vec2(0.0,1.0);
	vec4 a = from_clamped(uv - sdir*stretch);
	vec4 b = to_clamped(uv + sdir*stretch);
	return mix(a, b, smoothstep(0.4,0.6,pe));
}
void fragment(){ COLOR = transition(UV); }
