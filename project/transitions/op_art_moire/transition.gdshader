shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float scale : hint_range(40.0,260.0) = 130.0;
uniform float churn : hint_range(0.0,1.0) = 0.5;
vec4 transition(vec2 uv){
	float e = clamp(progress,0.0,1.0);
	vec2 q = uv * vec2(tr_ratio(),1.0) * scale;
	float p1 = sin(q.x) * sin(q.y);
	float ang = (0.3 + churn*0.8) * e * 3.1416;
	vec2 r = vec2(cos(ang)*q.x - sin(ang)*q.y, sin(ang)*q.x + cos(ang)*q.y);
	float p2 = sin(r.x*1.04) * sin(r.y*1.04);
	float moire = (p1*p2) * 0.5 + 0.5;
	float thr = 1.0 - e*1.4;
	float m = smoothstep(thr-0.15, thr+0.15, moire + (e-0.5)*0.6);
	return mix(from_at(uv), to_at(uv), clamp(m,0.0,1.0));
}
void fragment(){ COLOR = transition(UV); }
