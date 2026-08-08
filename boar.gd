extends AnimatedSprite2D

# =========================================================================
#  TO'NG'IZ (BOAR) — alohida kadrlardan animatsiya + SUVDAN QOCHISH (TUZATILGAN)
# =========================================================================

const DIR := "res://assets/boar/"

const IDLE_FRAMES := 7
const RUN_FRAMES := 4

var move_speed := 30.0
var target := Vector2.ZERO
var facing := "SE"
var is_walking := false
var world = null

var dir_vectors := {
	"NE": Vector2(1, -1),
	"NW": Vector2(-1, -1),
	"SE": Vector2(1, 1),
	"SW": Vector2(-1, 1),
}


func _ready() -> void:
	world = get_parent()
	_build_animations()
	_ensure_on_land()
	play("idle_SE")
	_pick_new_target()


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for facing_dir in ["NE", "NW", "SE", "SW"]:
		_add_anim_from_files(frames, "idle_" + facing_dir,
			"boar_" + facing_dir + "_idle_", IDLE_FRAMES, 8.0)
		_add_anim_from_files(frames, "run_" + facing_dir,
			"boar_" + facing_dir + "_run_", RUN_FRAMES, 10.0)
	sprite_frames = frames


func _add_anim_from_files(frames: SpriteFrames, anim_name: String,
		prefix: String, count: int, fps: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	for i in range(count):
		var tex := load(DIR + prefix + str(i) + ".png") as Texture2D
		if tex != null:
			frames.add_frame(anim_name, tex)


# MUHIM: hayvon dunyoning bolasi -> position ALLAQACHON local. to_local KERAK EMAS.
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
	var step := to_target.normalized() * move_speed * delta
	var next_pos := position + step
	if _is_water_at(next_pos):
		is_walking = false
		_pick_new_target()
		return

	var anim := "run_" + facing
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
