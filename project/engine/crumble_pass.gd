extends "res://engine/effect_pass.gd"


var world: Node3D = null
var cam: Camera3D = null
var sun: DirectionalLight3D = null
var we: WorldEnvironment = null
var mat3d: StandardMaterial3D = null
var pieces: Array[MeshInstance3D] = []
var src_tex: Texture2D = null
var phys: Object = null

var bake_key: String = ""
var mesh_key: String = ""
var home: PackedVector3Array = PackedVector3Array()
var delay: PackedFloat32Array = PackedFloat32Array()
var baked: PackedFloat32Array = PackedFloat32Array()
var baked_count: int = 0
var baked_steps: int = 0


func _init() -> void:
	super()
	disable_3d = false
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	if rect != null:
		rect.visible = false
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	cam = Camera3D.new()
	cam.name = "Cam"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	world.add_child(cam)
	cam.current = true
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 0.9
	world.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.82
	we = WorldEnvironment.new()
	we.name = "WorldEnv"
	we.environment = env
	world.add_child(we)
	mat3d = StandardMaterial3D.new()
	mat3d.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat3d.roughness = 0.75
	mat3d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR


func set_input(tex: Texture2D) -> void:
	src_tex = tex
	if rect != null:
		rect.texture = tex
	if mat3d != null:
		mat3d.albedo_texture = tex


func clear_pieces() -> void:
	for mi: MeshInstance3D in pieces:
		if is_instance_valid(mi):
			mi.queue_free()
	pieces = []
