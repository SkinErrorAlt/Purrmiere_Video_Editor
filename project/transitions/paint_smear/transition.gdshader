shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float amount : hint_range(0.05,0.6) = 0.28;
uniform float scale : hint_range(1.0,10.0) = 4.0;
vec2 dir_of(int d){ if(d==1){return vec2(-1.0,0.0);} else if(d==2){return vec2(0.0,1.0);} else if(d==3){return vec2(0.0,-1.0);} return vec2(1.0,0.0); }
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	vec2 d = dir_of(direction);
	float n = tr_fbm(uv*scale + d*e);
	vec2 off = d * amount * n * sin(e*TR_PI);
	float m = smoothstep(0.3,0.7,e);
	vec3 col = vec3(0.0); float a=0.0;
	const int N=6;
	for(int i=0;i<N;i++){ float t=float(i)/float(N-1); vec4 s = mix(from_clamped(uv - off*t), to_clamped(uv - off*t), m); col+=s.rgb; a+=s.a; }
	return vec4(col/float(N), a/float(N));
}
void fragment(){ COLOR = transition(UV); }
