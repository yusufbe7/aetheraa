extends Node2D

# =========================================================================
#  SLIME (JELATIN) — ko'k jelatinli mob
#  Sprite KERAK EMAS: o'zini kod bilan chizadi (procedural).
#  Sakraydi, suvdan qochib kezadi, siqilib-cho'ziladi (squash & stretch).
#  Keyinchalik Blender/pixel sprite bilan almashtirish mumkin.
# =========================================================================

var world = null

# ---- Harakat ----
var move_speed := 34.0
var target := Vector2.ZERO
var is_moving := false

# ---- Sakrash (hop) — z balandlik ----
var z := 0.0
var z_vel := 0.0
const HOP_POWER := 62.0
const GRAVITY := 220.0
var on_ground := true
var _hop_cooldown := 0.0

# ---- Squash & stretch ----
var squash := 0.0        # 0 = normal, + = yassi (yerga tekkanda), - = cho'zilgan

# ---- Ko'rinish ----
const BODY_R := 9.0
var _wobble := 0.0
var hp := 3               # jon (qilich bilan urilganda kamayadi)
var _hurt_flash := 0.0
var _terr := 0.0          # turgan katakning terrasa balandligi (px)

# Slime rangi (5-rasmdagi ko'k kristall jelatin)
const COL_BODY := Color(0.30, 0.72, 0.92, 0.82)
const COL_CORE := Color(0.62, 0.90, 0.98, 0.9)
const COL_EDGE := Color(0.15, 0.45, 0.70, 0.9)


func _ready() -> void:
	world = get_parent()
	_wobble = randf() * TAU
	_ensure_on_land()
	_pick_new_target()
	# Har slime biroz boshqacha o'lchamda — jonli ko'rinadi
	var s := randf_range(0.85, 1.25)
	scale = Vector2(s, s)


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
		var dist := randf_range(40.0, 130.0)
		var candidate := position + Vector2(cos(angle), sin(angle)) * dist
		if not _is_water_at(candidate):
			target = candidate
			is_moving = true
			return
	is_moving = false


func _process(delta: float) -> void:
	_wobble += delta * 6.0
	if _hurt_flash > 0.0:
		_hurt_flash -= delta

	# ---- Sakrash fizikasi ----
	if not on_ground:
		z += z_vel * delta
		z_vel -= GRAVITY * delta
		if z <= 0.0:
			z = 0.0
			z_vel = 0.0
			on_ground = true
			squash = 1.0        # yerga tekkanda yassilanadi
			world_play_land()
	else:
		# Yerdagi siqilishni asta tiklaymiz
		squash = lerpf(squash, 0.0, delta * 8.0)

	# ---- Manzil tomon sakrab yurish ----
	if is_moving:
		var to_target := target - position
		var dist := to_target.length()
		if dist < 6.0:
			is_moving = false
			_hop_cooldown = randf_range(0.6, 1.8)
		else:
			# Faqat yerda turganda sakraydi
			if on_ground:
				_hop_cooldown -= delta
				if _hop_cooldown <= 0.0:
					_start_hop()
			# Havoda oldinga siljiydi
			if not on_ground:
				var step := to_target.normalized() * move_speed * delta
				var next_pos := position + step
				if _is_water_at(next_pos):
					is_moving = false
					_pick_new_target()
				else:
					position = next_pos
	else:
		_hop_cooldown -= delta
		if _hop_cooldown <= 0.0:
			_pick_new_target()

	# Terrasa balandligi — yer ustida tursin
	if world != null and world.has_method("_lift_px"):
		var cell := world.local_to_grid(position)
		_terr = world._lift_px(cell.x, cell.y)

	queue_redraw()


func _start_hop() -> void:
	on_ground = false
	z_vel = HOP_POWER
	squash = -0.6            # sakraganda cho'ziladi
	_hop_cooldown = randf_range(0.2, 0.5)


func world_play_land() -> void:
	# Ovoz bo'lsa chaladi (ixtiyoriy)
	if world != null and world.has_method("play_sfx"):
		pass  # xohlasangiz: world.play_sfx("step", -18.0, 0.2)


# Qilich bilan urilganda main.gd shu funksiyani chaqirishi mumkin
func hit(damage: int = 1) -> void:
	hp -= damage
	_hurt_flash = 0.15
	# Urilganda sakrab qochadi
	on_ground = true
	_start_hop()
	if world != null:
		var away := (position - world.player.position).normalized() if world.player != null else Vector2.RIGHT
		target = position + away * randf_range(80.0, 140.0)
		is_moving = true
	if hp <= 0:
		_die()


func _die() -> void:
	# Slime yiqilganda "Jelatin" item beradi (agar tizim mavjud bo'lsa)
	if world != null and world.has_method("add_item"):
		world.add_item("Jelatin", "sapphire", 1)
		if world.has_method("_toast"):
			world._toast("Jelatin", "sapphire", 1)
	queue_free()


# =========================================================================
#  PROCEDURAL CHIZISH — ko'k jelatin blob
# =========================================================================
func _draw() -> void:
	# z balandlik (sakrash) + terrasa balandligi: tanani yuqoriga siljitamiz
	var lift := Vector2(0.0, -z - _terr)

	# ---- Soya (yerda — terrasa usti) ----
	var shadow_w := BODY_R * 1.6 * (1.0 - z / 120.0)
	shadow_w = maxf(shadow_w, BODY_R * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ellipse(Vector2(0.0, 2.0 - _terr), shadow_w, shadow_w * 0.4,
		Color(0.0, 0.0, 0.0, 0.22 * (1.0 - z / 140.0)))

	# ---- Squash & stretch ----
	# squash > 0 -> yassi (kengroq, pastroq); < 0 -> cho'zilgan (torroq, balandroq)
	var sx := 1.0 + squash * 0.35 + sin(_wobble) * 0.04
	var sy := 1.0 - squash * 0.35 - sin(_wobble) * 0.04
	var w := BODY_R * sx
	var h := BODY_R * sy
	var c := lift + Vector2(0.0, -h)

	var body := COL_BODY
	var edge := COL_EDGE
	if _hurt_flash > 0.0:
		body = Color(1.0, 0.75, 0.75, 0.9)
		edge = Color(0.9, 0.3, 0.3, 0.95)

	# Tana (jelatin blob) — pasti tekisroq, tepasi dumaloq
	_draw_ellipse(c, w, h, body)
	_draw_ellipse_outline(c, w, h, edge, 1.5)
	# Yorug'lik dog'i (yaltiroq)
	_draw_ellipse(c + Vector2(-w * 0.3, -h * 0.35), w * 0.28, h * 0.22,
		Color(1, 1, 1, 0.55))
	# Ichki kristall yadro
	_draw_ellipse(c + Vector2(0.0, h * 0.1), w * 0.4, h * 0.4, COL_CORE)

	# Ko'zlar
	var eye_off := w * 0.34
	_draw_ellipse(c + Vector2(-eye_off, -h * 0.05), 1.7, 2.1, Color(0.05, 0.1, 0.15))
	_draw_ellipse(c + Vector2(eye_off, -h * 0.05), 1.7, 2.1, Color(0.05, 0.1, 0.15))
	# Ko'z yaltirog'i
	_draw_ellipse(c + Vector2(-eye_off + 0.5, -h * 0.05 - 0.6), 0.6, 0.6, Color(1, 1, 1, 0.9))
	_draw_ellipse(c + Vector2(eye_off + 0.5, -h * 0.05 - 0.6), 0.6, 0.6, Color(1, 1, 1, 0.9))


# Ellips (to'ldirilgan) — poligon bilan
func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 18
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var n := 18
	for i in range(n + 1):
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width)
