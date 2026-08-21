extends AnimatedSprite2D

# =========================================================================
#  SLIME (JELATIN) — ko'k dushman mob (War / wars_vault sprite paketi)
#  Kadr: 96x32.  Idle(7), Hurt(11), Death(14).
#  - Suvdan qochib kezadi
#  - Sichqoncha ustiga kelsa chetlarida OQ border yonadi (shader)
#  - Qo'l/qilich/bolta/har qanday narsa bilan urib bo'ladi -> o'ladi -> Jelatin
# =========================================================================

const DIR := "res://assets/slime/"
const FRAME_W := 96
const FRAME_H := 32

const IDLE_FRAMES := 7
const HURT_FRAMES := 11
const DEATH_FRAMES := 14
const JUMP_FRAMES := 22    # Start-up(9)+Up(1)+Fall(5)+Down(1)+Land(6)

var world: AetheraWorld = null

var move_speed := 28.0
var target := Vector2.ZERO
var is_moving := false
var _cooldown := 0.0

var hp := 5                  # qo'l bilan 5 marta, asbob bilan 3 marta
var dying := false
var hurting := false

# ---- HUJUM (personajni ta'qib qiladi va uradi) ----
const AGGRO_DIST := 120.0    # shu masofada personajni ko'rsa quvadi
const ATTACK_DIST := 20.0    # shu masofada zarba beradi
const ATTACK_CD := 1.2       # zarbalar orasidagi vaqt
var _attack_t := 0.0
var jumping := false         # hujum (jump) animatsiyasi o'ynayapti

var _mat: ShaderMaterial = null


func _ready() -> void:
	world = get_parent() as AetheraWorld
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # piksel aniq
	_build_animations()

	# OQ border shader (hover)
	var sh := load("res://assets/outline.gdshader")
	if sh != null:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("hovered", false)
		material = _mat

	play("idle")
	_ensure_on_land()
	_pick_new_target()
	# ~32x32 o'lchamda ko'rinsin (kadr 96x32, tana kichik) -> kichraytiramiz
	var s := randf_range(0.62, 0.72)
	scale = Vector2(s, s)


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_anim(frames, "idle",  DIR + "slime_blue_idle.png",  IDLE_FRAMES, 8.0, true)
	_add_anim(frames, "hurt",  DIR + "slime_blue_hurt.png",  HURT_FRAMES, 16.0, false)
	_add_anim(frames, "death", DIR + "slime_blue_death.png", DEATH_FRAMES, 14.0, false)
	_add_anim(frames, "jump",  DIR + "slime_blue_jump.png",  JUMP_FRAMES, 22.0, false)
	sprite_frames = frames


func _add_anim(frames: SpriteFrames, anim_name: String, path: String,
		count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("Slime sprite topilmadi: " + path)
		return
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame(anim_name, atlas)


# To'siqmi? Suv / daraxt / tosh / bino — hammasidan chetlab o'tadi.
# OYOQ nuqtasini tekshiramiz (sprite markazi emas) — aks holda oyoq suvda qoladi.
const FEET_OFF := 6.0
func _is_water_at(local_pos: Vector2) -> bool:
	if world == null or not world.has_method("_is_occupied_cell"):
		return false
	var cell: Vector2i = world.local_to_grid(local_pos + Vector2(0.0, FEET_OFF))
	return world._is_occupied_cell(cell)


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
		var dist := randf_range(40.0, 130.0)
		var candidate := position + Vector2(cos(angle), sin(angle)) * dist
		if not _is_water_at(candidate):
			target = candidate
			is_moving = true
			return
	is_moving = false


func _process(delta: float) -> void:
	# Terrasa balandligi (elevation yoqilgan bo'lsa)
	if world != null and world.has_method("_lift_px"):
		var c := world.local_to_grid(position)
		offset.y = -world._lift_px(c.x, c.y) / maxf(scale.y, 0.01)

	# Hover -> oq border (sichqoncha sprite ustidami?)
	if _mat != null:
		_mat.set_shader_parameter("hovered", _is_hovered())

	if dying:
		return

	# Hujum (jump) o'ynayotganda joyida turadi
	if jumping:
		return

	if _attack_t > 0.0:
		_attack_t -= delta

	# ---- HUJUM: personaj yaqin bo'lsa quvadi va uradi ----
	if not hurting and world != null and world.player != null:
		var to_p := world.player.position - position
		var pdist := to_p.length()
		if pdist < AGGRO_DIST:
			if pdist <= ATTACK_DIST:
				# Yetdi — sakrab hujum qiladi (cooldown bilan)
				if _attack_t <= 0.0:
					_attack_t = ATTACK_CD
					_do_attack()
			else:
				# Personajga qarab yaqinlashadi (to'siqdan chetlab)
				var step := to_p.normalized() * move_speed * delta
				var nxt := position + step
				if not _is_water_at(nxt):
					position = nxt
					if absf(to_p.x) > 0.5:
						flip_h = to_p.x < 0.0
			return

	# ---- Oddiy kezish (personaj uzoqda) ----
	if is_moving and not hurting:
		var to_t := target - position
		var d := to_t.length()
		if d < 5.0:
			is_moving = false
			_cooldown = randf_range(0.7, 2.0)
		else:
			var step := to_t.normalized() * move_speed * delta
			var nxt := position + step
			if _is_water_at(nxt):
				is_moving = false
				_pick_new_target()
			else:
				position = nxt
				if absf(to_t.x) > 0.5:
					flip_h = to_t.x < 0.0
	else:
		if not hurting:
			_cooldown -= delta
			if _cooldown <= 0.0:
				_pick_new_target()


# Sakrab hujum: jump animatsiyasi, oxirida (yerga tushganda) zarba tegadi
func _do_attack() -> void:
	jumping = true
	play("jump")
	await _wait_anim("jump")
	jumping = false
	if dying:
		return
	# Yerga tushdi — hali yaqinda bo'lsa jonini kamaytiradi
	if world != null and world.player != null \
			and world.player.position.distance_to(position) <= ATTACK_DIST + 8.0:
		if world.has_method("hurt_player"):
			world.hurt_player(1)
	play("idle")


# Sichqoncha sprite (tanasi) ustidami? — hover uchun ishonchli tekshiruv
func _is_hovered() -> bool:
	var ml := to_local(get_global_mouse_position())
	return absf(ml.x) < 30.0 and absf(ml.y) < 16.0


# Qo'l/qilich/bolta/har qanday narsa bilan urilganda main.gd chaqiradi
func hit(damage: int = 1) -> void:
	if dying:
		return
	hp -= damage
	if hp <= 0:
		_die()
		return
	_do_hurt()


func _do_hurt() -> void:
	hurting = true
	play("hurt")
	# Urilganda personajdan sal qochadi
	if world != null and world.player != null:
		var away := (position - world.player.position).normalized()
		target = position + away * randf_range(70.0, 120.0)
	await _wait_anim("hurt")
	if dying:
		return
	hurting = false
	is_moving = true
	play("idle")


func _die() -> void:
	dying = true
	is_moving = false
	play("death")
	await _wait_anim("death")
	# Jelatin beradi
	if world != null and world.has_method("add_item"):
		world.add_item("Jelatin", "jelly", 1)
		if world.has_method("_toast"):
			world._toast("Jelatin", "jelly", 1)
	if world != null and world.has_method("play_sfx"):
		world.play_sfx("collect", -10.0, 0.1)
	queue_free()


# Animatsiya davomiyligini kutadi (frame_count / fps)
func _wait_anim(anim_name: String) -> void:
	var cnt := sprite_frames.get_frame_count(anim_name)
	var fps := sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		fps = 10.0
	await get_tree().create_timer(float(cnt) / fps).timeout
