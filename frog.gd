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

var world: AetheraWorld = null

var move_speed := 30.0
var target := Vector2.ZERO
var is_moving := false
var _cooldown := 0.0

var hp := 2
var dying := false
var _flash := 0.0
var _mat: ShaderMaterial = null


func _ready() -> void:
	world = get_parent() as AetheraWorld
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_animations()
	# OQ border shader (hover)
	var sh := load("res://assets/outline.gdshader")
	if sh != null:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("hovered", false)
		material = _mat
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


# To'siqmi? Suv / daraxt / tosh / bino — hammasidan chetlab o'tadi.
func _is_water_at(local_pos: Vector2) -> bool:
	if world == null or not world.has_method("_is_occupied_cell"):
		return false
	var cell: Vector2i = world.local_to_grid(local_pos)
	return world._is_occupied_cell(cell)


func _pick_new_target() -> void:
	for attempt in range(12):
		var angle := randf() * TAU
		var dist := randf_range(30.0, 100.0)
		var candidate := position + Vector2(cos(angle), sin(angle)) * dist
		if not _is_water_at(candidate):
			target = candidate
			is_moving = true
			return
	is_moving = false


func _process(delta: float) -> void:
	# Terrasa balandligi (yoqilgan bo'lsa)
	if world != null and world.has_method("_lift_px"):
		var c := world.local_to_grid(position)
		offset.y = -world._lift_px(c.x, c.y) / maxf(scale.y, 0.01)

	# Hover -> oq border (shader); urilganda oq flash (modulate)
	if _mat != null:
		_mat.set_shader_parameter("hovered", _is_hovered())
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(2.4, 2.4, 2.4)
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
			var nxt := position + to_t.normalized() * move_speed * delta
			if _is_water_at(nxt):
				is_moving = false
				_pick_new_target()
			else:
				position = nxt
				if absf(to_t.x) > 0.5:
					flip_h = to_t.x < 0.0
	else:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_pick_new_target()


# Sichqoncha sprite (tanasi) ustidami? — hover uchun ishonchli tekshiruv
func _is_hovered() -> bool:
	var ml := to_local(get_global_mouse_position())
	return absf(ml.x) < 13.0 and absf(ml.y) < 13.0


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
