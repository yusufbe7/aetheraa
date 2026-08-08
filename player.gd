extends AnimatedSprite2D

# =========================================================================
#  O'YINCHI (Body_A) — WASD + sichqoncha, 3 yo'nalishli animatsiya
#  Animatsiyalar: idle, walk, run, slice (chopish), crush (ezish)
#  Yo'nalish: Up / Down / Side (Side chapga flip bilan)
# =========================================================================

const DIR := "res://assets/player/"

# Har animatsiya: [prefiks, kadrlar soni, fps]
# Fayl nomi: {prefiks}_{Up|Down|Side}-Sheet.png
const ANIMS := {
	"idle":  ["Idle", 4, 6.0],
	"walk":  ["Walk", 6, 10.0],
	"run":   ["Run", 6, 12.0],
	"slice": ["Slice", 8, 12.0],
	"crush": ["Crush", 8, 12.0],
}
const FRAME_SIZE := 64

var move_speed := 70.0
var target := Vector2.ZERO
var is_walking := false
var facing := "Down"       # Up / Down / Side
var world = null

# Ish holati: bo'sh, yoki chopyapti/ezyapti (harakatni to'xtatadi)
var busy := false


func _ready() -> void:
	world = get_parent()
	_build_animations()
	centered = true
	_play_dir("idle")
	_ensure_on_land()


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim_key in ANIMS:
		var info = ANIMS[anim_key]
		var prefix = info[0]
		var count = info[1]
		var fps = info[2]
		for d in ["Up", "Down", "Side"]:
			var full_name = anim_key + "_" + d
			var path = DIR + prefix + "_" + d + "-Sheet.png"
			_add_sheet(frames, full_name, path, count, fps)
	sprite_frames = frames


func _add_sheet(frames: SpriteFrames, anim_name: String, path: String,
		count: int, fps: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	var tex := load(path) as Texture2D
	if tex == null:
		return
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(anim_name, atlas)


# Yo'nalishga qarab to'g'ri animatsiyani o'ynaydi
func _play_dir(anim_key: String) -> void:
	var full = anim_key + "_" + facing
	if animation != full:
		play(full)


func _is_water_at(local_pos: Vector2) -> bool:
	if world == null or not world.has_method("_ground_type"):
		return false
	var cell: Vector2i = world.local_to_grid(local_pos)
	return world._ground_type(cell.x, cell.y) == "water"


func _ensure_on_land() -> void:
	if not _is_water_at(position):
		return
	for radius in range(1, 40):
		for a in range(0, 360, 30):
			var ang := deg_to_rad(a)
			var p := position + Vector2(cos(ang), sin(ang)) * radius * 8.0
			if not _is_water_at(p):
				position = p
				return


func _process(delta: float) -> void:
	if busy:
		return   # chopish/ezish paytida yurmaydi

	# 1) KLAVIATURA (WASD)
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1

	if input_dir != Vector2.ZERO:
		is_walking = false
		_move_by(input_dir.normalized(), delta)
		return

	# 2) SICHQONCHA manzili
	if is_walking:
		var to_target := target - position
		if to_target.length() < 4.0:
			is_walking = false
			_play_dir("idle")
		else:
			_move_by(to_target.normalized(), delta)
	else:
		_play_dir("idle")


func _move_by(dir_screen: Vector2, delta: float) -> void:
	# Izometrik moslash: Y ni cho'zamiz
	var iso_dir := Vector2(dir_screen.x, dir_screen.y * 2.0).normalized()
	var step := iso_dir * move_speed * delta
	var next_pos := position + step
	if _is_water_at(next_pos):
		_play_dir("idle")
		return
	position = next_pos

	# Yo'nalishni aniqlaymiz (qaysi o'q kuchliroq)
	if abs(dir_screen.y) > abs(dir_screen.x):
		facing = "Up" if dir_screen.y < 0 else "Down"
	else:
		facing = "Side"
		flip_h = dir_screen.x < 0   # chapga -> flip

	_play_dir("run")


func walk_to(local_pos: Vector2) -> void:
	if _is_water_at(local_pos):
		return
	target = local_pos
	is_walking = true


# =========================================================================
#  CHOPISH / EZISH (keyingi qadamda daraxt/tosh bilan bog'lanadi)
# =========================================================================
# anim_key: "slice" (daraxt) yoki "crush" (tosh)
func do_action(anim_key: String) -> void:
	if busy:
		return
	busy = true
	var full = anim_key + "_" + facing
	play(full)
	# Animatsiya tugaguncha kutamiz (taxminan 8 kadr / fps)
	await get_tree().create_timer(0.7).timeout
	busy = false
	_play_dir("idle")
