extends CharacterBody3D

# =========================================================================
#  3D PLAYER (portal shahri, 1-bosqich) — vaqtinchalik capsule tana.
#  Boshqaruv: WASD yurish, sichqoncha qarash (3-shaxs), SPACE sakrash,
#  ESC — sichqonchani ozod qilish/qaytarish.
#  Keyinroq capsule o'rniga haqiqiy 3D personaj modeli qo'yiladi.
# =========================================================================

const SPEED := 7.0
const JUMP := 6.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0025

var _pitch := 0.0
var cam_pivot: Node3D = null
var camera: Camera3D = null
var _spawn_pos := Vector3(0.0, 20.0, 0.0)


func _ready() -> void:
	# To'qnashuv shakli (capsule)
	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.4
	caps.height = 1.8
	col.shape = caps
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	# Ko'rinadigan tana (vaqtinchalik capsule mesh)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mesh.mesh = cm
	mesh.position = Vector3(0.0, 0.9, 0.0)
	add_child(mesh)

	# Uchinchi shaxs kamera: pivot (bosh balandligida) + orqadagi kamera
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0.0, 1.6, 0.0)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 6.0)   # personajdan 6 birlik orqada
	camera.far = 3000.0
	camera.current = true
	cam_pivot.add_child(camera)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 0.6)
		cam_pivot.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP

	var iv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		iv.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		iv.z += 1.0
	if Input.is_key_pressed(KEY_A):
		iv.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		iv.x += 1.0

	# Yo'nalishni personaj qaragan tomonga (yaw) burib olamiz
	var dir := transform.basis * iv
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()

	# Agar shahar ostiga tushib ketsa — qayta tepaga
	if global_position.y < -100.0:
		global_position = _spawn_pos
		velocity = Vector3.ZERO
