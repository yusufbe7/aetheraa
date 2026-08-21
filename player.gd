extends AnimatedSprite2D

# =========================================================================
# AETHERA — Character0 Player
# 460x460 sprite-sheet
#
# 8x5 / 5 ta izometrik yo'nalish:
# Down
# DownSide
# Side
# UpSide
# Up
# =========================================================================

const DIR := "res://assets/player/Character0/"
const FRAME_SIZE := 460

const ROWS := {
	"Down": 0,
	"DownSide": 1,
	"Side": 2,
	"UpSide": 3,
	"Up": 4
}

const ANIM_FPS := {
	"idle": 8.0,
	"walk": 12.0,
	"run": 16.0,
	"action": 14.0,
	"short": 10.0
}

# Asosiy animatsiyalar
const FILES := {
	"idle": "Character0_Idle.png",
	"walk": "Character0_Walk.png",
	"run": "Character0_Run.png",

	# Oddiy harakatlar
	"swing": "Character0_Swing.png",
	"damage": "Character0_Damage.png",
	"interact": "Character0_Interact.png",
	"sit": "Character0_Sit.png",
	"getup": "Character0_GetUp.png",
	"die": "Character0_Die.png",
	"dig": "Character0_Dig.png",
	"fish": "Character0_Fish.png",
	"sword_attack": "Character0_SwordAttack.png",

	# Asboblar
	"idle_axe": "Character0_IdleHoldingTool_Axe.png",
	"walk_axe": "Character0_WalkHoldingTool_Axe.png",
	"run_axe": "Character0_Run_Axe.png",
	"swing_axe": "Character0_Swing_Axe.png",

	"idle_pickaxe": "Character0_IdleHoldingTool_Pickaxe.png",
	"walk_pickaxe": "Character0_WalkHoldingTool_Pickaxe.png",
	"run_pickaxe": "Character0_Run_PickAxe.png",
	"swing_pickaxe": "Character0_Swing_PickAxe.png",

	"idle_sword": "Character0_IdleHoldingTool_Sword.png",
	"walk_sword": "Character0_WalkHoldingTool_Sword.png",
	"run_sword": "Character0_Run_Sword.png",
	"sword_attack_sword": "Character0_SwordAttack_Sword.png",

	"idle_shovel": "Character0_IdleHoldingTool_Showel.png",
	"walk_shovel": "Character0_WalkHoldingTool_Showel.png",
	"dig_shovel": "Character0_Dig_Showel.png",

	"idle_hammer": "Character0_IdleHoldingTool_Hammer.png",
	"walk_hammer": "Character0_WalkHoldingTool_Hammer.png",
	"run_hammer": "Character0_Run_Hammer.png",
	"swing_hammer": "Character0_Swing_Hammer.png",

	"idle_fishing": "Character0_IdleHoldingTool_Fishingpole.png",
	"walk_fishing": "Character0_WalkHoldingTool_Fishingpole.png",
	"run_fishing": "Character0_Run_Fishingpole.png",
	"fish_fishing": "Character0_Fish_Fishingpole.png",

	"idle_watercan": "Character0_IdleHoldingTool_WaterCan.png",
	"walk_watercan": "Character0_WalkHoldingTool_WaterCan.png",
	"run_watercan": "Character0_Run_WaterCan.png"
}

var move_speed := 118.0   # oddiy harakat (sekinlashtirildi)
var run_speed := 175.0    # SHIFT — tezroq

var target := Vector2.ZERO
var is_walking := false
var path: Array = []      # yo'l waypointlari (Vector2 ro'yxati)
var path_i := 0           # hozirgi waypoint indeksi

var facing := "Down"

var world = null
var busy := false


func _ready() -> void:
	world = get_parent()
	centered = true
	scale = Vector2(0.12, 0.12)
	_build_animations()
	_play_animation("idle")


# =========================================================================
# ANIMATSIYALARNI QURISH
# =========================================================================

func _build_animations() -> void:
	var frames := SpriteFrames.new()

	if frames.has_animation("default"):
		frames.remove_animation("default")

	for key in FILES:
		var path: String = DIR + FILES[key]
		var tex := load(path) as Texture2D

		if tex == null:
			push_warning("Character0 topilmadi: " + path)
			continue

		var frame_count := int(tex.get_width() / FRAME_SIZE)

		if frame_count <= 0:
			continue

		for dir_name in ROWS:
			var anim_name = key + "_" + dir_name
			frames.add_animation(anim_name)

			var fps := _get_fps(key)
			frames.set_animation_speed(anim_name, fps)

			var looping: bool = (
				key == "idle"
				or key == "walk"
				or key == "run"
				or key.begins_with("idle_")
				or key.begins_with("walk_")
				or key.begins_with("run_")
			)

			frames.set_animation_loop(anim_name, looping)

			for i in range(frame_count):
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(
					i * FRAME_SIZE,
					ROWS[dir_name] * FRAME_SIZE,
					FRAME_SIZE,
					FRAME_SIZE
				)
				frames.add_frame(anim_name, atlas)

	sprite_frames = frames


func _get_fps(key: String) -> float:
	if (
		key == "swing"
		or key == "damage"
		or key == "interact"
		or key == "sit"
		or key == "getup"
		or key == "die"
		or key == "dig"
		or key == "fish"
		or key == "sword_attack"
		or key.begins_with("swing_")
		or key.begins_with("dig_")
		or key.begins_with("fish_")
		or key.begins_with("sword_attack_")
	):
		return ANIM_FPS["action"]

	return ANIM_FPS.get(key, 10.0)


# =========================================================================
# ANIMATSIYA
# =========================================================================

func _play_animation(base: String) -> void:
	if sprite_frames == null:
		return

	var anim_name := base + "_" + facing

	if not sprite_frames.has_animation(anim_name):
		return

	if animation != anim_name:
		play(anim_name)


# =========================================================================
# QAYSI ASBOB QO'LDA
# =========================================================================

func _get_tool_prefix() -> String:
	if world == null or not world.has_method("get_equipped"):
		return ""

	var equipped := str(world.get_equipped())

	match equipped:
		"Bolta", "axe", "Sehrli bolta":
			return "axe"
		"Kirka", "pickaxe", "Sehrli kirka":
			return "pickaxe"
		"Qilich", "sword", "Sehrli qilich":
			return "sword"
		"Belkurak", "shovel":
			return "shovel"
		"Qarmoq", "fishing_rod":
			return "fishing"
		"Bolg'a", "hammer":
			return "hammer"
		"Suv idishi", "watercan":
			return "watercan"
		_:
			return ""


# =========================================================================
# IDLE / WALK / RUN
# =========================================================================

func _update_animation(state: String) -> void:
	if busy:
		return

	var tool := _get_tool_prefix()
	var animation_base := state

	if tool != "":
		var tool_animation := state + "_" + tool
		if sprite_frames.has_animation(tool_animation + "_" + facing):
			animation_base = tool_animation

	_play_animation(animation_base)


# =========================================================================
# HARAKAT
# =========================================================================

func _process(delta: float) -> void:
	if busy:
		return
	# Sozlamalar menyusi ochiq bo'lsa personaj qimirlamaydi
	if world != null and world.get("settings_open"):
		return

	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0

	# WASD
	if input_dir != Vector2.ZERO:
		is_walking = false
		_move(input_dir.normalized(), delta)
		return

	# Yo'l bo'ylab yurish (pathfinding waypointlari)
	if is_walking:
		if path.is_empty():
			is_walking = false
			_update_animation("idle")
		else:
			var wp: Vector2 = path[path_i]
			var difference := wp - position
			if difference.length() > 4.0:
				_move(difference.normalized(), delta)
			else:
				# Shu waypointga yetdi -> keyingisiga o'tamiz
				path_i += 1
				if path_i >= path.size():
					is_walking = false
					path = []
					_update_animation("idle")
	else:
		_update_animation("idle")


# =========================================================================
# YURISH
# =========================================================================

func _move(dir: Vector2, delta: float) -> void:
	var speed := move_speed

	if Input.is_key_pressed(KEY_SHIFT):
		speed = run_speed

	# ISO movement
	var move_dir := Vector2(dir.x, dir.y * 0.82)

	if move_dir.length() > 0.001:
		move_dir = move_dir.normalized()

	var step := move_dir * speed * delta

	# To'siq tekshiruvi: suv / daraxt / tosh / bino ichiga kirmaymiz.
	# Devor bo'ylab sirg'anish: to'g'ridan bo'lmasa, X yoki Y bo'ylab urinamiz.
	var next_pos := position + step
	if _is_blocked(next_pos):
		var slide_x := position + Vector2(step.x, 0.0)
		var slide_y := position + Vector2(0.0, step.y)
		if not _is_blocked(slide_x):
			position = slide_x
		elif not _is_blocked(slide_y):
			position = slide_y
		else:
			# Butunlay to'silgan — turaveradi
			_update_animation("idle")
			return
	else:
		position = next_pos

	_set_facing(dir)

	# Personaj DOIM yuguradi (sekin "walk" emas). SHIFT — yanada tezroq.
	_update_animation("run")


# =========================================================================
# TO'SIQ TEKSHIRUVI
# =========================================================================

# Shu nuqtaga qadam tashlash mumkinmi?
# Dunyodan (main.gd) so'raymiz: suv / daraxt / tosh / bino bo'lsa - yo'q.
func _is_blocked(pos: Vector2) -> bool:
	if world == null or not world.has_method("_is_blocking_cell"):
		return false
	# Personaj kengligi hisobga olinadi - chetlarini ham tekshiramiz
	var checks := [
		pos,
		pos + Vector2(-5.0, 0.0),
		pos + Vector2(5.0, 0.0),
		pos + Vector2(0.0, 3.0),
	]
	for p in checks:
		if world._is_blocking_cell(world.local_to_grid(p)):
			return true
	return false


# =========================================================================
# YO'NALISH VA FLIP TUZATISHI
# =========================================================================

func _set_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	var abs_x: float = abs(dir.x)
	var abs_y: float = abs(dir.y)

	# Yo'nalishni aniqlash
	if abs_x > 0.3 and abs_y > 0.3:
		# Diagonal harakat
		if dir.y > 0:
			facing = "DownSide"
		else:
			facing = "UpSide"
	elif abs_x > abs_y:
		# To'g'ri yonlama harakat
		facing = "Side"
	elif dir.y > 0:
		# Vertikal: Pastga
		facing = "Down"
	else:
		# Vertikal: Tepaga
		facing = "Up"

	# Horizontal flip (Aylantirish) mantiqiy tuzatishi:
	# Agarda original sprite sheet'ingizdagi Side/DownSide/UpSide kadrlar
	# Standart bo'yicha CHAPGA qarab turgan bo'lsa (aksariyat assetlarda shunday):
	if dir.x > 0:
		flip_h = true  # O'ngga yuraganda ko'zgudek o'giradi
	elif dir.x < 0:
		flip_h = false # Chapga yuraganda asl holicha qoladi

	# ESLATMA: Agar spritelaringiz original holatda O'NGGA qarab turgan bo'lsa,
	# yuqoridagi true/false o'rinlarini almashtiring (dir.x > 0 uchun false, dir.x < 0 uchun true).


# =========================================================================
# MOUSE WALK
# =========================================================================

# Bitta nuqtaga yurish (yo'l = 1 waypoint)
func walk_to(local_pos: Vector2) -> void:
	follow_path([local_pos])


# Waypointlar ro'yxati bo'ylab yurish (A* natijasi)
func follow_path(points: Array) -> void:
	if busy:
		return
	path = points.duplicate()
	path_i = 0
	is_walking = path.size() > 0
	if path.size() > 0:
		target = path[path.size() - 1]
	else:
		_update_animation("idle")


# Hozir yuryaptimi?
func is_moving() -> bool:
	return is_walking


# Yurishni darhol to'xtatadi (native stop() bilan to'qnashmasin)
func stop_walking() -> void:
	path = []
	path_i = 0
	is_walking = false


# Chopish paytida personaj nishonga qarab tursin
func face_point(point: Vector2) -> void:
	var d := point - position
	if d.length() > 0.001:
		_set_facing(d.normalized())


# =========================================================================
# ACTION
# =========================================================================

func do_action(anim_key: String) -> void:
	if busy:
		return

	busy = true
	is_walking = false

	var tool := _get_tool_prefix()
	var animation_base := anim_key

	if tool != "":
		var tool_animation := anim_key + "_" + tool
		if sprite_frames.has_animation(tool_animation + "_" + facing):
			animation_base = tool_animation

	var full_animation := animation_base + "_" + facing

	if not sprite_frames.has_animation(full_animation):
		full_animation = anim_key + "_" + facing
		if not sprite_frames.has_animation(full_animation):
			busy = false
			_update_animation("idle")
			return

	play(full_animation)

	var frame_count := sprite_frames.get_frame_count(full_animation)
	var fps := sprite_frames.get_animation_speed(full_animation)

	if fps <= 0.0:
		fps = 10.0

	var duration := float(frame_count) / fps

	await get_tree().create_timer(duration).timeout

	busy = false
	_update_animation("idle")
