extends AnimatedSprite2D

# =========================================================================
#  QURBAQA (FROG) — kichik yashil critter
#  frog_green.png: 512x512, 32px kadrlar. Row 0 = oldinga qaragan idle (8 kadr).
#  - Suv yaqinida ham, quruqlikda ham kezadi (qurbaqa suvni yaxshi ko'radi)
#  - Sichqoncha ustiga kelsa yorqinlashadi, urilsa oq flash + qochadi
#  - O'lganda Go'sht beradi
# =========================================================================

const DIR := "res://assets/frog/"
const FRAME := 32
const IDLE_ROW := 0
const IDLE_FRAMES := 8

var world = null

var move_speed := 30.0
var target := Vector2.ZERO
var is_moving := false
var _cooldown := 0.0

var hp := 2
var dying := false
var _flash := 0.0


func _ready() -> void:
	world = get_parent()
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_animations()
	play("idle")
	_pick_new_target()
	var s := randf_range(0.7, 1.0)
	scale = Vector2(s, s)


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var tex := load(DIR + "frog_green.png") as Texture2D
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 7.0)
	frames.set_animation_loop("idle", true)
	if tex != null:
		for i in range(IDLE_FRAMES):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * FRAME, IDLE_ROW * FRAME, FRAME, FRAME)
			frames.add_frame("idle", atlas)
	else:
		push_warning("Frog sprite topilmadi: " + DIR + "frog_green.png")
	sprite_frames = frames


func _is_water_at(local_pos: Vector2) -> bool:
	if world == null or not world.has_method("_ground_type"):
		return false
	var cell: Vector2i = world.local_to_grid(local_pos)
	return world._ground_type(cell.x, cell.y) == "water"


func _pick_new_target() -> void:
	# Qurbaqa suvdan qochmaydi, lekin juda uzoq ketmaydi
	for attempt in range(12):
		var angle := randf() * TAU
		var dist := randf_range(30.0, 100.0)
		target = position + Vector2(cos(angle), sin(angle)) * dist
		is_moving = true
		return
	is_moving = false


func _process(delta: float) -> void:
	# Terrasa balandligi (yoqilgan bo'lsa)
	if world != null and world.has_method("_lift_px"):
		var c := world.local_to_grid(position)
		offset.y = -world._lift_px(c.x, c.y) / maxf(scale.y, 0.01)

	# Hover -> yorqinlashadi; urilganda oq flash
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(2.4, 2.4, 2.4)
	elif world != null and world.hovered_cell == world.local_to_grid(position):
		modulate = Color(1.5, 1.5, 1.5)
	else:
		modulate = Color(1, 1, 1)

	if dying:
		return

	if is_moving:
		var to_t := target - position
		var d := to_t.length()
		if d < 5.0:
			is_moving = false
			_cooldown = randf_range(0.8, 2.5)
		else:
			position += to_t.normalized() * move_speed * delta
			if absf(to_t.x) > 0.5:
				flip_h = to_t.x < 0.0
	else:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_pick_new_target()


# Qo'l/qilich/bolta/har qanday narsa bilan urilganda main.gd chaqiradi
func hit(damage: int = 1) -> void:
	if dying:
		return
	hp -= damage
	_flash = 0.15
	if world != null and world.player != null:
		var away := (position - world.player.position).normalized()
		target = position + away * randf_range(90.0, 160.0)
		is_moving = true
	move_speed = 70.0
	if hp <= 0:
		_die()


func _die() -> void:
	dying = true
	if world != null and world.has_method("add_item"):
		world.add_item("Go'sht", "meat", 1)
		if world.has_method("_toast"):
			world._toast("Go'sht", "meat", 1)
	if world != null and world.has_method("play_sfx"):
		world.play_sfx("collect", -10.0, 0.1)
	queue_free()
