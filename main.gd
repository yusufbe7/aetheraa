extends Node2D

# =========================================================================
#  AETHERA — Procgen dunyo + O'yinchi + Chopish + Animatsiyali daraxt
#  + DEPTH SORTING (personaj daraxt orqasiga o'tsa to'siladi)
# =========================================================================

const TILE_W := 32.0
const TILE_H := 16.0

const ASSET_DIR := "res://assets/"

var GROUND := {
	"water": ["tile_098", "tile_099", "tile_100", "tile_104", "tile_105"],
	"dirt":  ["tile_000", "tile_001", "tile_002", "tile_003"],
	"grass": ["tile_024", "tile_025", "tile_033", "tile_034", "tile_035"],
}

var DECOR := {
	"flower": ["tile_053", "tile_055", "tile_056", "tile_057"],
	"plant":  ["tile_041", "tile_042", "tile_043", "tile_044"],
}

# ---- YANGI TOSHLAR (rock papkasidan) ----
const ROCK_DIR := "res://assets/rocks/"
# [fayl nomi, kadr eni, kadr balandligi]
var ROCK_DEFS := [
	["res64_black_small_rock_32x32", 32, 32],
	["res64_black_medium_rock_32x32", 32, 32],
	["res64_black_small_cone_rock_32x32", 32, 32],
	["res64_black_small_plateau_rock_32x32", 32, 32],
	["res64_black_small_triple_rock_32x32", 32, 32],
	["res64_black_large_rock_64x64", 64, 64],
]
var _rock_data := []

const TREE_DIR := "res://assets/trees/"
const TREE_FPS := 8.0
var TREE_DEFS := [
	# Faqat classical (past) daraxtlar — pine (baland) olib tashlandi
	["AnimatedTreeCoolColor",   64, 64, 16],
	["AnimatedTreeWarmColor",   64, 64, 16],
	["AnimatedTreeStartAutumn", 64, 64, 16],
	["AnimatedAutum",           64, 64, 16],
	["AnimatedSnow",            64, 64, 16],
]
var _tree_data := []
var tree_anim_frame := 0
var _anim_timer := 0.0

# ---- O'TIN (yog'och resursi) ----
const WOODS_PATH := "res://assets/trees/Woods.png"
var _woods_tex: Texture2D = null
# Yerda uchib-sakrab yurgan o'tinlar (har biri alohida fizika bilan)
# Har biri: {pos, vel, z, zvel, variant, born, state}
#   state: "fly_up" (sakrab chiqyapti) -> "settle" (yotdi) -> "to_player" (uchyapti)
var wood_items := []
# Yig'ilgan resurslar
var wood_count := 0
var stone_count := 0

var _tex_cache := {}

var height_noise := FastNoiseLite.new()
var decor_noise := FastNoiseLite.new()
const WORLD_SEED := 1337

var cam_offset := Vector2.ZERO
var zoom := 2.5
const ZOOM_MIN := 1.0
const ZOOM_MAX := 6.0

var hovered_cell := Vector2i(0, 0)
var is_panning := false
var pan_last := Vector2.ZERO
var press_start := Vector2.ZERO
var did_drag := false

var player: Node2D = null
var follow_player := true

var broken := {}
var chop_target = null
var chop_kind := ""

# Daraxt/tosh sog'ligi (nechта urish qolgani). Kalit: Vector2i, qiymat: int
var decor_hp := {}
const TREE_MAX_HP := 3
const ROCK_MAX_HP := 4

# Silkinish effekti: qaysi katak, qancha vaqt silkinadi
var shake_cell = null
var shake_timer := 0.0


func _ready() -> void:
	height_noise.seed = WORLD_SEED
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height_noise.frequency = 0.03
	decor_noise.seed = WORLD_SEED + 999
	decor_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	decor_noise.frequency = 0.15

	for d in TREE_DEFS:
		var t = load(TREE_DIR + d[0] + ".png") as Texture2D
		if t != null:
			_tree_data.append({"tex": t, "fw": d[1], "fh": d[2], "frames": d[3]})

	_woods_tex = load(WOODS_PATH) as Texture2D

	for r in ROCK_DEFS:
		var rt = load(ROCK_DIR + r[0] + ".png") as Texture2D
		if rt != null:
			_rock_data.append({"tex": rt, "fw": r[1], "fh": r[2]})

	if has_node("Player"):
		player = get_node("Player")
		# Personajni "ko'rinmas" qilamiz — biz uni _draw ichida to'g'ri
		# chuqurlikda o'zimiz chizamiz (depth sorting uchun)
		player.visible = false

	cam_offset = get_viewport_rect().size / 2.0
	_apply_transform()


func _apply_transform() -> void:
	position = cam_offset
	scale = Vector2(zoom, zoom)
	queue_redraw()


func _get_tex(tile_name: String) -> Texture2D:
	if not _tex_cache.has(tile_name):
		_tex_cache[tile_name] = load(ASSET_DIR + tile_name + ".png")
	return _tex_cache[tile_name]

func _stable_pick(list: Array, col: int, row: int, salt: int) -> String:
	var h = int(abs(hash(Vector3i(col, row, salt))))
	return list[h % list.size()]

func _stable_index(col: int, row: int, salt: int, size: int) -> int:
	var h = int(abs(hash(Vector3i(col, row, salt))))
	return h % size

func _ground_type(col: int, row: int) -> String:
	var h = height_noise.get_noise_2d(col, row)
	if h < -0.25:
		return "water"
	elif h < 0.0:
		return "dirt"
	else:
		return "grass"

func _decor_type(col: int, row: int, ground: String) -> String:
	if ground == "water":
		return ""
	var d = decor_noise.get_noise_2d(col, row)
	var r = float(int(abs(hash(Vector2i(col, row)))) % 1000) / 1000.0
	if ground == "grass":
		if d > 0.55 and r < 0.6:
			return "tree"
		elif d > 0.3 and r < 0.25:
			return "tree"
		elif r < 0.10:
			return "flower"
		elif r < 0.22:
			return "plant"
		elif r > 0.95:
			return "rock"
	elif ground == "dirt":
		if r < 0.08:
			return "rock"
		elif d > 0.5 and r < 0.15:
			return "tree"
	return ""

func _decor_at(col: int, row: int) -> String:
	if broken.has(Vector2i(col, row)):
		return ""
	return _decor_type(col, row, _ground_type(col, row))


func grid_to_local(col: int, row: int) -> Vector2:
	return Vector2((col - row) * (TILE_W / 2.0), (col + row) * (TILE_H / 2.0))

func local_to_grid(pos: Vector2) -> Vector2i:
	var c = (pos.x / (TILE_W / 2.0) + pos.y / (TILE_H / 2.0)) / 2.0
	var r = (pos.y / (TILE_H / 2.0) - pos.x / (TILE_W / 2.0)) / 2.0
	return Vector2i(int(floor(c)), int(floor(r)))


func _draw_ground(tile_name: String, col: int, row: int) -> void:
	var tex = _get_tex(tile_name)
	var center = grid_to_local(col, row)
	draw_texture(tex, center - Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0))

func _draw_rock(col: int, row: int) -> void:
	if _rock_data.is_empty():
		return
	var ri = _stable_index(col, row, 11, _rock_data.size())
	var info = _rock_data[ri]
	var tex = info["tex"]
	var fw = info["fw"]
	var fh = info["fh"]
	var center = grid_to_local(col, row)
	# Tosh pastki cheti katak "poli"ga tekislanadi
	var pos = center - Vector2(fw / 2.0, fh - TILE_H / 2.0)
	draw_texture(tex, pos)


func _draw_decor(tile_name: String, col: int, row: int) -> void:
	var tex = _get_tex(tile_name)
	var center = grid_to_local(col, row)
	draw_texture(tex, center - Vector2(tex.get_width() / 2.0, tex.get_height() - TILE_H / 2.0))

func _draw_tree(col: int, row: int) -> void:
	if _tree_data.is_empty():
		return
	var ti = _stable_index(col, row, 7, _tree_data.size())
	var info = _tree_data[ti]
	var tex = info["tex"]
	var fw = info["fw"]
	var fh = info["fh"]
	var fcount = info["frames"]
	var frame = tree_anim_frame % fcount
	var center = grid_to_local(col, row)
	# Silkinish: agar shu katak urilayotgan bo'lsa — chapga-o'ngga tebranadi
	if shake_cell != null and shake_cell == Vector2i(col, row) and shake_timer > 0:
		center.x += sin(shake_timer * 40.0) * 2.0
	var src = Rect2(frame * fw, 0, fw, fh)
	var dst_pos = center - Vector2(fw / 2.0, fh - TILE_H / 2.0)
	draw_texture_rect_region(tex, Rect2(dst_pos, Vector2(fw, fh)), src)

# Yerda yotgan o'tinni chizadi (Woods.png dan bitta log)
# Kichik log variantlari (Woods.png chap tomonidan, har biri 16x14)
const LOG_SRC := [
	Rect2(0, 0, 16, 14),
	Rect2(16, 0, 16, 14),
]

# Daraxt yiqilganda 2 ta o'tin sakratib chiqaramiz
func _spawn_wood(cell: Vector2i) -> void:
	var center = grid_to_local(cell.x, cell.y)
	var amount = randi_range(2, 3)   # har daraxt 2-3 o'tin beradi
	for i in range(amount):
		# Har tomonga ajralib uchadi (aylana bo'ylab tarqaladi)
		var angle = randf() * TAU
		var speed = randf_range(18, 35)
		wood_items.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"z": 0.0,
			"zvel": randf_range(45, 70),
			"variant": i % LOG_SRC.size(),
			"state": "fly",
			"born": Time.get_ticks_msec(),
		})
	print("Daraxt yiqildi -> ", amount, " o'tin chiqdi")

# Barcha uchib-yotgan o'tinlarni chizadi (z = balandlik effekti)
func _draw_all_wood() -> void:
	if _woods_tex == null:
		return
	for item in wood_items:
		var src = LOG_SRC[item["variant"]]
		# z balandlik: rasm yuqoriga suriladi (sakragandek), pastda soya
		var draw_pos = item["pos"] - Vector2(8, 7) - Vector2(0, item["z"])
		# Soya (yerda)
		draw_circle(item["pos"] + Vector2(0, 2), 5.0 - item["z"] * 0.04, Color(0, 0, 0, 0.2))
		draw_texture_rect_region(_woods_tex, Rect2(draw_pos, Vector2(16, 14)), src)


# Personajning hozirgi animatsiya kadrini to'g'ri joyda chizamiz
func _draw_player() -> void:
	if player == null:
		return
	var spr = player as AnimatedSprite2D
	if spr.sprite_frames == null:
		return
	var anim = spr.animation
	if not spr.sprite_frames.has_animation(anim):
		return
	var fr = spr.frame
	var tex = spr.sprite_frames.get_frame_texture(anim, fr)
	if tex == null:
		return
	var w = tex.get_width()
	var h = tex.get_height()
	# Markazlangan, flip hisobga olinadi
	var pos = player.position - Vector2(w / 2.0, h / 2.0)
	if spr.flip_h:
		# Flip uchun teskari chizamiz
		draw_texture_rect(tex, Rect2(player.position + Vector2(w/2.0, -h/2.0), Vector2(-w, h)), false)
	else:
		draw_texture(tex, pos)


func _visible_range() -> Array:
	var vp = get_viewport_rect().size
	var corners = [to_local(Vector2(0,0)), to_local(Vector2(vp.x,0)), to_local(Vector2(0,vp.y)), to_local(vp)]
	var min_c = 1 << 30; var max_c = -(1 << 30)
	var min_r = 1 << 30; var max_r = -(1 << 30)
	for p in corners:
		var g = local_to_grid(p)
		min_c = min(min_c, g.x); max_c = max(max_c, g.x)
		min_r = min(min_r, g.y); max_r = max(max_r, g.y)
	return [min_c-4, max_c+6, min_r-4, max_r+6]

func _draw() -> void:
	var rng = _visible_range()
	var c0: int = rng[0]; var c1: int = rng[1]
	var r0: int = rng[2]; var r1: int = rng[3]

	# Personaj chuqurligi (col+row)
	var p_depth = 2147483647   # juda katta = eng oxirida (agar player yo'q bo'lsa)
	if player != null:
		var pc = local_to_grid(player.position)
		p_depth = pc.x + pc.y

	# 1) YER (fon)
	for s in range(r0 + c0, r1 + c1 + 1):
		for col in range(c0, c1 + 1):
			var row = s - col
			if row < r0 or row > r1:
				continue
			var ground = _ground_type(col, row)
			_draw_ground(_stable_pick(GROUND[ground], col, row, 1), col, row)

	# 2) OBYEKTLAR + PERSONAJ — chuqurlik (s = col+row) bo'yicha
	var player_drawn = false
	for s in range(r0 + c0, r1 + c1 + 1):
		# Personaj shu chuqurlikda bo'lsa — obyektlardan OLDIN chizamiz
		# (shunda oldindagi (kattaroq s) obyektlar personajni to'sadi)
		if not player_drawn and s > p_depth:
			_draw_player()
			player_drawn = true

		for col in range(c0, c1 + 1):
			var row = s - col
			if row < r0 or row > r1:
				continue
			var deco = _decor_at(col, row)
			if deco == "tree":
				_draw_tree(col, row)
			elif deco == "rock":
				_draw_rock(col, row)
			elif deco != "":
				_draw_decor(_stable_pick(DECOR[deco], col, row, 2), col, row)

	# Agar hali chizilmagan bo'lsa (eng oldinda) — oxirida chizamiz
	if not player_drawn:
		_draw_player()

	# Barcha o'tinlarni chizamiz (personajdan keyin — ustida ko'rinadi)
	_draw_all_wood()

	var hc = grid_to_local(hovered_cell.x, hovered_cell.y)
	draw_colored_polygon(PackedVector2Array([
		hc + Vector2(0, -TILE_H/2.0), hc + Vector2(TILE_W/2.0, 0),
		hc + Vector2(0, TILE_H/2.0), hc + Vector2(-TILE_W/2.0, 0),
	]), Color(1, 1, 0.4, 0.25))


func _process(delta: float) -> void:
	hovered_cell = local_to_grid(to_local(get_global_mouse_position()))

	_anim_timer += delta
	if _anim_timer >= 1.0 / TREE_FPS:
		_anim_timer = 0.0
		tree_anim_frame = (tree_anim_frame + 1) % 16

	if follow_player and player != null:
		var vp = get_viewport_rect().size
		var wanted = vp / 2.0 - player.position * zoom
		cam_offset = cam_offset.lerp(wanted, 8.0 * delta)
		position = cam_offset

	# Silkinish taymerini kamaytiramiz
	if shake_timer > 0:
		shake_timer -= delta

	# O'tin fizikasi (sakrash, tushish, personajga uchish)
	_update_wood(delta)

	if chop_target != null and player != null:
		var target_pos = grid_to_local(chop_target.x, chop_target.y)
		var dist = player.position.distance_to(target_pos)
		if dist < 12.0:
			# Yetib bordi — to'xtaydi va uradi
			player.walk_to(player.position)
			if player.has_method("do_action") and not player.busy:
				var anim = "slice" if chop_kind == "tree" else "crush"
				await player.do_action(anim)
				# Bir urish — hp kamayadi
				var max_hp = TREE_MAX_HP if chop_kind == "tree" else ROCK_MAX_HP
				var hp = decor_hp.get(chop_target, max_hp) - 1
				# Silkinish effekti
				shake_cell = chop_target
				shake_timer = 0.25
				if hp <= 0:
					# Yiqildi
					broken[chop_target] = true
					decor_hp.erase(chop_target)
					# O'tin/tosh tashlaymiz (yerda yotadi)
					if chop_kind == "tree":
						# Daraxt yiqildi -> 2 ta o'tin SAKRAB chiqadi
						_spawn_wood(chop_target)
					chop_target = null
					chop_kind = ""
					shake_cell = null
				else:
					# Hali tirik — hp saqlaymiz, yana uradi
					decor_hp[chop_target] = hp

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(get_viewport().get_mouse_position(), 1.1); return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(get_viewport().get_mouse_position(), 1.0/1.1); return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_panning = true
				did_drag = false
				pan_last = event.position
				press_start = event.position
			else:
				is_panning = false
				if not did_drag:
					_click_world()
			return

	if event is InputEventMouseMotion and is_panning:
		var d = event.position - pan_last
		if event.position.distance_to(press_start) > 6.0:
			did_drag = true
			follow_player = false
		cam_offset += d
		pan_last = event.position
		position = cam_offset
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL:
			_zoom_at(get_viewport_rect().size / 2.0, 1.15)
		elif event.keycode == KEY_MINUS:
			_zoom_at(get_viewport_rect().size / 2.0, 1.0/1.15)
		elif event.keycode == KEY_SPACE:
			follow_player = true


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before = to_local(screen_pos)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	scale = Vector2(zoom, zoom)
	cam_offset += screen_pos - to_global(before)
	position = cam_offset


func _click_world() -> void:
	if player == null:
		return
	follow_player = true
	var cell = local_to_grid(to_local(get_global_mouse_position()))
	var deco = _decor_at(cell.x, cell.y)
	if deco == "tree" or deco == "rock":
		chop_target = cell
		chop_kind = deco
		if player.has_method("walk_to"):
			player.walk_to(grid_to_local(cell.x, cell.y))
	else:
		chop_target = null
		if player.has_method("walk_to"):
			player.walk_to(to_local(get_global_mouse_position()))


# O'tinlarni har kadr yangilaydi: sakrash -> tushish -> personajga uchish
func _update_wood(delta: float) -> void:
	if wood_items.is_empty():
		return
	var now = Time.get_ticks_msec()
	var gravity := 140.0
	var survivors := []
	for item in wood_items:
		var age = now - item["born"]

		if item["state"] == "fly":
			# Sakrash: z balandlik, gorizontal harakat, tortishish
			item["z"] += item["zvel"] * delta
			item["zvel"] -= gravity * delta
			item["pos"] += item["vel"] * delta
			item["vel"] *= 0.90    # ishqalanish (sekinlashadi)
			# Yerga tushdimi?
			if item["z"] <= 0 and item["zvel"] < 0:
				item["z"] = 0
				item["zvel"] = 0
				item["vel"] = Vector2.ZERO
				item["state"] = "settle"

		elif item["state"] == "settle":
			# Yerda yotibdi. Personaj yaqin (va o'tin 0.8s+ yotgan) bo'lsa -> uchadi
			if player != null and age > 800:
				var d = player.position.distance_to(item["pos"])
				if d < 40.0:
					item["state"] = "to_player"

		elif item["state"] == "to_player":
			# Personajga uchib boradi (tezlashib)
			if player == null:
				continue
			var to_p = player.position - item["pos"]
			var dist = to_p.length()
			if dist < 6.0:
				# Yetdi — yig'iladi
				wood_count += 1
				print("Yog'och yig'ildi! Jami: ", wood_count)
				continue   # bu o'tin yo'qoladi (survivors ga qo'shilmaydi)
			item["pos"] += to_p.normalized() * 220.0 * delta

		survivors.append(item)

	wood_items = survivors
