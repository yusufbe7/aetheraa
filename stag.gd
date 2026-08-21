extends AnimatedSprite2D

# =========================================================================
#  BUG'U (STAG) — strip animatsiya + SUVDAN QOCHIB kezish (TUZATILGAN)
# =========================================================================

const DIR := "res://assets/stag/"

const FRAME_W := 32
const FRAME_H := 41
const IDLE_FRAMES := 24
const WALK_FRAMES := 11

var move_speed := 25.0
var target := Vector2.ZERO
var facing := "SE"
var is_walking := false
var world: AetheraWorld = null

var hp := 4
var dying := false
var _flash := 0.0
var _mat: ShaderMaterial = null

var dir_vectors := {
	"NE": Vector2(1, -1),
	"NW": Vector2(-1, -1),
	"SE": Vector2(1, 1),
	"SW": Vector2(-1, 1),
}


func _ready() -> void:
	world = get_parent() as AetheraWorld
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_animations()
	# OQ border shader (hover)
	var sh := load("res://assets/outline.gdshader")
	if sh != null:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("hovered", false)
		material = _mat
	# Boshlanganda o'zi quruqlikda ekaniga ishonch hosil qilamiz
	_ensure_on_land()
	play("idle_SE")
	_pick_new_target()


# Sichqoncha sprite (tanasi) ustidami? — hover uchun ishonchli tekshiruv
func _is_hovered() -> bool:
	var ml := to_local(get_global_mouse_position())
	return absf(ml.x) < 14.0 and absf(ml.y) < 20.0


# Qo'l/qilich/bolta/har qanday narsa bilan urilganda main.gd chaqiradi
func hit(damage: int = 1) -> void:
	if dying:
		return
	hp -= damage
	_flash = 0.15
	# Urilganda qochib ketadi
	if world != null and world.player != null:
		var away := (position - world.player.position).normalized()
		target = position + away * randf_range(120.0, 200.0)
		is_walking = true
	move_speed = 55.0   # qo'rqib tezlashadi
	if hp <= 0:
		_die()


func _die() -> void:
	dying = true
	if world != null and world.has_method("add_item"):
		world.add_item("Go'sht", "meat", 2)
		world.add_item("Leather", "leather", 1)
		if world.has_method("_toast"):
			world._toast("Go'sht", "meat", 2)
			world._toast("Leather", "leather", 1)
	if world != null and world.has_method("play_sfx"):
		world.play_sfx("collect", -8.0, 0.1)
	queue_free()


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for facing_dir in ["NE", "NW", "SE", "SW"]:
		_add_anim(frames, "idle_" + facing_dir,
			DIR + "critter_stag_" + facing_dir + "_idle.png",
			IDLE_FRAMES, 8.0, true)
		_add_anim(frames, "walk_" + facing_dir,
			DIR + "critter_stag_" + facing_dir + "_walk.png",
			WALK_FRAMES, 10.0, true)
	sprite_frames = frames


func _add_anim(frames: SpriteFrames, anim_name: String, path: String,
		frame_count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	var tex := load(path) as Texture2D
	if tex == null:
		return
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame(anim_name, atlas)


# MUHIM: hayvon dunyoning bolasi, shuning uchun position ALLAQACHON local.
# to_local KERAK EMAS. To'g'ridan-to'g'ri grid'ga o'giramiz.
func _is_water_at(local_pos: Vector2) -> bool:
	if world == null or not world.has_method("_ground_type"):
		return false
	var cell: Vector2i = world.local_to_grid(local_pos)
	return world._ground_type(cell.x, cell.y) == "water"


# Agar hayvon suvda paydo bo'lgan bo'lsa — yaqin quruqlikka ko'chiramiz
func _ensure_on_land() -> void:
	if not _is_water_at(position):
		return
	# Spiral bo'ylab yaqin quruqlik qidiramiz
	for radius in range(1, 40):
		for a in range(0, 360, 30):
			var ang := deg_to_rad(a)
			var p := position + Vector2(cos(ang), sin(ang)) * radius * 8.0
			if not _is_water_at(p):
				position = p
				return


func _pick_new_target() -> void:
	for attempt in range(20):
		var angle := randf() * TAU
		var dist := randf_range(40, 120)
		var candidate := position + Vector2(cos(angle), sin(angle)) * dist
		if not _is_water_at(candidate):
			target = candidate
			is_walking = true
			return
	is_walking = false
	play("idle_" + facing)


func _process(delta: float) -> void:
	# Terrasa balandligi — hayvon yer ustida tursin (suzib yurmasin)
	if world != null and world.has_method("_lift_px"):
		var cell := world.local_to_grid(position)
		offset.y = -world._lift_px(cell.x, cell.y)

	# Hover -> oq border (shader); urilganda oq flash (modulate)
	if _mat != null:
		_mat.set_shader_parameter("hovered", _is_hovered())
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(2.4, 2.4, 2.4)
	else:
		modulate = Color(1, 1, 1)

	if not is_walking:
		return
	var to_target := target - position
	if to_target.length() < 3.0:
		is_walking = false
		play("idle_" + facing)
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		_pick_new_target()
		return

	facing = _best_facing(to_target)
	# Keyingi qadamni oldindan tekshiramiz
	var step := to_target.normalized() * move_speed * delta
	var next_pos := position + step
	if _is_water_at(next_pos):
		# Oldinda suv — to'xtab, yangi quruqlik manzili tanlaymiz
		is_walking = false
		_pick_new_target()
		return

	var anim := "walk_" + facing
	if animation != anim:
		play(anim)
	position = next_pos


func _best_facing(v: Vector2) -> String:
	var best := "SE"
	var best_dot := -999.0
	for d in dir_vectors:
		var dv: Vector2 = dir_vectors[d].normalized()
		var dot := v.normalized().dot(dv)
		if dot > best_dot:
			best_dot = dot
			best = d
	return best
