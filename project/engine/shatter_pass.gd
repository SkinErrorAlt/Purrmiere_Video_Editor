extends SubViewport


var world: Node3D = null
var cam: Camera3D = null
var sun: DirectionalLight3D = null
var we: WorldEnvironment = null
var mat3d: StandardMaterial3D = null
var glass_mat: ShaderMaterial = null
var back_mat: StandardMaterial3D = null
var back_mi: MeshInstance3D = null
var dust_mm: MultiMeshInstance3D = null
var dust_mat: ShaderMaterial = null
var dust_p0: PackedVector3Array = PackedVector3Array()
var dust_v: PackedVector3Array = PackedVector3Array()
var dust_delay: PackedFloat32Array = PackedFloat32Array()
var dust_size: PackedFloat32Array = PackedFloat32Array()
var dust_g: float = 9.8
var pieces: Array[MeshInstance3D] = []
var from_tex: Texture2D = null
var to_tex: Texture2D = null
var phys: Object = null

var bake_key: String = ""
var mesh_key: String = ""
var home: PackedVector3Array = PackedVector3Array()
var delay: PackedFloat32Array = PackedFloat32Array()
var baked: PackedFloat32Array = PackedFloat32Array()
var baked_count: int = 0
var baked_steps: int = 0
var h: float = 5.0


func _init() -> void:
	transparent_bg = true
	disable_3d = false
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	size = Vector2i(2, 2)
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
	glass_mat = ShaderMaterial.new()
	glass_mat.shader = load("res://engine/glass_shard.gdshader")
	back_mat = StandardMaterial3D.new()
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	back_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	back_mi = MeshInstance3D.new()
	back_mi.name = "Back"
	back_mi.material_override = back_mat
	world.add_child(back_mi)
	dust_mat = ShaderMaterial.new()
	dust_mat.shader = load("res://engine/dust_particle.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 0
	dust_mm = MultiMeshInstance3D.new()
	dust_mm.name = "Dust"
	dust_mm.multimesh = mm
	dust_mm.material_override = dust_mat
	dust_mm.visible = false
	world.add_child(dust_mm)


func set_sources(a: Texture2D, b: Texture2D) -> void:
	from_tex = a
	to_tex = b
	if mat3d != null:
		mat3d.albedo_texture = a
	if glass_mat != null:
		glass_mat.set_shader_parameter("clip_tex", a)
	if back_mat != null:
		back_mat.albedo_texture = b


func clear_pieces() -> void:
	for mi: MeshInstance3D in pieces:
		if is_instance_valid(mi):
			mi.queue_free()
	pieces = []
