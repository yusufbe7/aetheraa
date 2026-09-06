extends Node3D

# =========================================================================
#  3D SHAHAR (portal olami) — 1-BOSQICH: alohida sinov sahnasi.
#  Godot'da city3d.tscn ni oching va F6 bilan ishga tushiring.
#  WASD + sichqoncha bilan shahar bo'ylab yuring (ESC — sichqoncha ozod).
#  Hamma narsa KODDA quriladi (import UID kerak emas). 2-bosqichda portal
#  shu sahnaga olib o'tadigan bo'ladi.
# =========================================================================

const CITY_PATH := "res://assets/city3d/futuristic_city.fbx"


func _ready() -> void:
	_setup_environment()
	var spawn := _setup_city()
	_setup_player(spawn)


func _setup_environment() -> void:
	# Osmon + ambient yorug'lik
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	# Quyosh (soya bilan)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


# Shaharni yuklaydi, collision yasaydi, spawn nuqtasini (ustida) qaytaradi.
func _setup_city() -> Vector3:
	var packed = load(CITY_PATH)
	if packed == null:
		push_warning("3D shahar topilmadi/import bo'lmadi: " + CITY_PATH)
		return Vector3(0.0, 20.0, 0.0)
	var city = packed.instantiate()
	add_child(city)
	_add_collision_recursive(city)

	# Shaharning umumiy hajmini (AABB) topib, player'ni ustiga tashlaymiz
	var box = _merge_aabb(city, null)
	if box == null:
		return Vector3(0.0, 20.0, 0.0)
	var c: Vector3 = box.get_center()
	return Vector3(c.x, box.end.y + 3.0, c.z)


func _add_collision_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()   # to'siq: player o'tib ketmaydi
	for ch in node.get_children():
		_add_collision_recursive(ch)


func _merge_aabb(node: Node, acc):
	if node is MeshInstance3D:
		var a: AABB = node.get_aabb()
		a = node.global_transform * a
		if acc == null:
			acc = a
		else:
			acc = acc.merge(a)
	for ch in node.get_children():
		acc = _merge_aabb(ch, acc)
	return acc


func _setup_player(spawn: Vector3) -> void:
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player3d.gd"))
	player.position = spawn
	player.set("_spawn_pos", spawn)
	add_child(player)
