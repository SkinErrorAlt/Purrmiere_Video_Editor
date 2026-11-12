shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform vec4 bolt_color : source_color = vec4(0.6,0.82,1.0,1.0);
uniform float intensity : hint_range(0.0,2.5) = 1.3;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	float peak = sin(e*TR_PI);
	float bx = 0.5 + (tr_fbm(vec2(uv.y*5.0, 2.0))-0.5)*0.5 + sin(uv.y*34.0 + 3.0)*0.02;
	float dist = abs(uv.x - bx)*tr_ratio();
	float bolt = exp(-dist*dist*450.0) + exp(-dist*dist*45.0)*0.3;
	bolt *= peak * (0.7 + 0.6*tr_hash(vec2(floor(uv.y*40.0), floor(e*30.0))));
	float rev = smoothstep(0.45,0.62,e);
	vec4 base = mix(from_at(uv), to_at(uv), rev);
	float flash = exp(-pow((e-0.5)/0.08,2.0));
	base.rgb += bolt_color.rgb*bolt_color.a*bolt*intensity*2.2;
	base.rgb = mix(base.rgb, vec3(base.a), flash*0.5);
	return vec4(clamp(base.rgb,0.0,1.0), base.a);
}
void fragment(){ COLOR = transition(UV); }
