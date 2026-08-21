extends Control

# =========================================================================
#  AETHERA — BOSH EKRAN (Main Menu / Title Screen)
#
#  Dizayn: ISO-CORE uslubi —
#    * tekis to'q kulrang fon
#    * katta PIKSEL-ART logotip "AETHERA" (kod bilan chiziladi, rasm shart emas)
#      ustida qarag'ay, qo'ziqorin va shox-shabba bezaklari
#    * ostida kichik "DEMO" yozuvi
#    * menyu: PLAY (katta) / New World / Settings / Close Game (kichik)
#
#  Agar res://assets/ui/logo.png bo'lsa — o'sha rasm ishlatiladi.
#  3 til: English / Русский / O'zbek (Lang autoload).
# =========================================================================

const WORLD_SCENE := "res://main.tscn"
const LOGO_PATH := "res://assets/ui/logo.png"

const FONT_PATH := "res://assets/ui/PressStart2P-Regular.ttf"

var _menu_font: Font = null
# --- RANGLAR (ISO-CORE) ---
const COL_BG := Color(0.145, 0.145, 0.165)
const COL_LETTER := Color(0.949, 0.925, 0.867)      # krem harflar
const COL_LETTER_EDGE := Color(0.129, 0.118, 0.106) # to'q kontur
const COL_SHADOW := Color(0.055, 0.055, 0.070)
const COL_SEL := Color(1.0, 1.0, 1.0)
const COL_ITEM := Color(0.72, 0.74, 0.76)
const COL_DISABLED := Color(0.40, 0.42, 0.45)
const COL_WOOD := Color(0.255, 0.180, 0.118)
const COL_LEAF := Color(0.286, 0.600, 0.290)
const COL_LEAF_DARK := Color(0.180, 0.420, 0.200)

var _logo: Texture2D = null

# Menyu bandlari
var items := [
	{"key": "menu.play", "id": "play", "big": true, "enabled": false},
	{"key": "menu.new", "id": "new", "big": false, "enabled": true},
	{"key": "menu.settings", "id": "settings", "big": false, "enabled": true},
	{"key": "menu.exit", "id": "exit", "big": false, "enabled": true},
]
var selected := 1

var _t := 0.0
var _no_save_flash := 0.0
var _loading := false        # "Loading World..." ekrani
var _load_frames := 0

var panel: SettingsPanel = null
var settings_open := false
var _lang_badge := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_logo = load(LOGO_PATH) if ResourceLoader.exists(LOGO_PATH) else null
	_menu_font = load(FONT_PATH) as Font

	panel = SettingsPanel.new()
	panel.in_game = false

	# Saqlangan o'yin bor bo'lsa PLAY yoqiladi va u tanlanadi
	if Lang.has_save():
		items[0]["enabled"] = true
		selected = 0

	Lang.language_changed.connect(func(): queue_redraw())
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if _no_save_flash > 0.0:
		_no_save_flash = maxf(0.0, _no_save_flash - delta)

	# "Loading World..." bir-ikki kadr ko'rinib, keyin sahna almashadi
	if _loading:
		_load_frames += 1
		if _load_frames >= 3:
			_loading = false
			get_tree().change_scene_to_file(WORLD_SCENE)
			return
	queue_redraw()


# =========================================================================
#  CHIZISH
# =========================================================================
func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), COL_BG)

	if _loading:
		_center(vp.x / 2.0, vp.y / 2.0, Lang.t("menu.loading"), 17, COL_SEL)
		return

	_draw_logo(vp)
	_draw_menu(vp)
	_draw_lang_badge(vp)

	if _no_save_flash > 0.0:
		var a := clampf(_no_save_flash / 0.6, 0.0, 1.0)
		_center(vp.x / 2.0, vp.y * 0.92, Lang.t("menu.no_save"), 14,
			Color(0.95, 0.55, 0.45, a))

	if settings_open:
		panel.draw_panel(self, vp, get_local_mouse_position(), null)


# -------------------------------------------------------------------------
#  LOGOTIP
# -------------------------------------------------------------------------
func _draw_logo(vp: Vector2) -> void:
	var cx := vp.x / 2.0

	if _logo != null:
		var lw := float(_logo.get_width())
		var lh := float(_logo.get_height())
		var s := minf(1.0, minf(vp.x * 0.72, 900.0) / lw)
		draw_texture_rect(_logo, Rect2(Vector2(cx - lw * s / 2.0, vp.y * 0.07),
			Vector2(lw * s, lh * s)), false)
		return

	# --- Piksel-art sarlavha ---
	var title := "AETHERA"
	# Piksel kattaligi ekranga moslanadi (harf 5 piksel keng + 1 bo'shliq)
	var px: float = floorf(clampf(vp.x / 78.0, 4.0, 14.0))
	var word_w: float = float(title.length()) * 6.0 * px - px
	var x0: float = cx - word_w / 2.0
	var y0: float = vp.y * 0.085

	# Shox-shabba bezaklari — harflar ORTIDA
	_branches(x0, y0, word_w, px)
	# Harflar
	_pixel_word(title, x0, y0, px)
	# Qarag'ay + qo'ziqorin — harflar USTIDA, o'rtada turadi
	_logo_tree(Vector2(cx, y0 + 7.0 * px * 0.82), px)

	# "DEMO"
	var dpx: float = maxf(3.0, floorf(px * 0.52))
	var dw: float = 4.0 * 6.0 * dpx - dpx
	_pixel_word("DEMO", cx - dw / 2.0, y0 + 7.0 * px + px * 2.6, dpx)


# 5x7 piksel shrift (faqat logotip uchun kerakli harflar)
const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"R": ["####.", "#...#", "#...#", "####.", "#..#.", "#...#", "#...#"],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


# Bitta so'zni piksel-art qilib chizadi: soya -> qalin kontur -> krem to'ldirish
func _pixel_word(word: String, x: float, y: float, px: float) -> void:
	# 1) Soya (pastga surilgan qalin siluet)
	_word_pass(word, x, y + px * 1.6, px, COL_SHADOW, true)
	# 2) Qalin to'q kontur
	_word_pass(word, x, y, px, COL_LETTER_EDGE, true)
	# 3) Krem to'ldirish
	_word_pass(word, x, y, px, COL_LETTER, false)


# bold=true bo'lsa har piksel 3x3 qilib chiziladi (kontur effekti)
func _word_pass(word: String, x: float, y: float, px: float,
		col: Color, bold: bool) -> void:
	for i in range(word.length()):
		var ch := word[i]
		if not GLYPHS.has(ch):
			continue
		var rows: Array = GLYPHS[ch]
		var gx: float = x + float(i) * 6.0 * px
		for r in range(rows.size()):
			var line: String = rows[r]
			for c in range(line.length()):
				if line[c] != "#":
					continue
				var rx: float = gx + float(c) * px
				var ry: float = y + float(r) * px
				if bold:
					draw_rect(Rect2(rx - px, ry - px, px * 3.0, px * 3.0), col)
				else:
					draw_rect(Rect2(rx, ry, px, px), col)


# Harflar orasidan o'tuvchi shox va yaproqlar
func _branches(x0: float, y0: float, w: float, px: float) -> void:
	var y_top: float = y0 - px * 0.5
	var pts := [
		[Vector2(x0 - px * 1.2, y_top + px * 2.0), Vector2(x0 + w * 0.22, y_top - px * 0.8)],
		[Vector2(x0 + w * 0.30, y_top - px * 0.6), Vector2(x0 + w * 0.46, y_top + px * 1.6)],
		[Vector2(x0 + w * 0.62, y_top + px * 1.2), Vector2(x0 + w * 0.86, y_top - px * 0.9)],
		[Vector2(x0 + w * 0.90, y_top - px * 0.4), Vector2(x0 + w + px * 1.4, y_top + px * 2.2)],
	]
	for seg in pts:
		draw_line(seg[0], seg[1], COL_WOOD, px * 0.8)
		# Uchidagi yaproq
		draw_rect(Rect2(seg[1].x - px * 0.9, seg[1].y - px * 0.9, px * 1.8, px * 1.8),
			COL_LEAF)
	# Pastdan chiqib turgan ikki shox
	var yb: float = y0 + 7.0 * px + px * 0.4
	draw_line(Vector2(x0 - px * 0.8, yb - px * 1.6),
		Vector2(x0 + w * 0.10, yb + px * 0.6), COL_WOOD, px * 0.7)
	draw_line(Vector2(x0 + w + px * 0.8, yb - px * 1.6),
		Vector2(x0 + w * 0.90, yb + px * 0.6), COL_WOOD, px * 0.7)


# Logotip o'rtasidagi qarag'ay + o't + qo'ziqorin
func _logo_tree(base: Vector2, px: float) -> void:
	var h: float = px * 7.0
	# O't tepaligi
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-px * 3.4, 0),
		base + Vector2(-px * 2.2, -px * 1.0),
		base + Vector2(px * 2.2, -px * 1.0),
		base + Vector2(px * 3.4, 0),
		base + Vector2(px * 2.4, px * 0.9),
		base + Vector2(-px * 2.4, px * 0.9),
	]), COL_LEAF_DARK)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-px * 2.8, -px * 0.3),
		base + Vector2(-px * 1.8, -px * 1.0),
		base + Vector2(px * 1.8, -px * 1.0),
		base + Vector2(px * 2.8, -px * 0.3),
	]), COL_LEAF)
	# Poya
	draw_rect(Rect2(base.x - px * 0.5, base.y - px * 1.9, px, px * 2.0), COL_WOOD)
	# Uch qatlam qarag'ay
	for i in range(3):
		var f := float(i)
		var ly: float = base.y - px * 1.6 - f * h * 0.24
		var lw: float = px * (3.6 - f * 0.9)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x, ly - h * 0.34),
			Vector2(base.x + lw, ly),
			Vector2(base.x - lw, ly),
		]), COL_LEAF_DARK if i == 0 else COL_LEAF)
	# Qo'ziqorin (chapda)
	var mp := base + Vector2(-px * 2.4, -px * 0.2)
	draw_rect(Rect2(mp.x - px * 0.35, mp.y - px * 0.9, px * 0.7, px * 0.9),
		Color(0.92, 0.88, 0.80))
	draw_colored_polygon(PackedVector2Array([
		mp + Vector2(-px * 1.0, -px * 0.9),
		mp + Vector2(0, -px * 1.9),
		mp + Vector2(px * 1.0, -px * 0.9),
	]), Color(0.82, 0.24, 0.20))


# -------------------------------------------------------------------------
#  MENYU
# -------------------------------------------------------------------------
func _menu_metrics(vp: Vector2) -> Array:
	var big := int(clampf(vp.y * 0.055, 22.0, 34.0))
	var small := int(clampf(vp.y * 0.028, 13.0, 18.0))
	var start_y: float = vp.y * 0.545
	return [big, small, start_y]


func _draw_menu(vp: Vector2) -> void:
	var cx := vp.x / 2.0
	var m := _menu_metrics(vp)
	var big: int = m[0]
	var small: int = m[1]
	var y: float = m[2]

	for i in range(items.size()):
		var it: Dictionary = items[i]
		var fs: int = big if bool(it["big"]) else small
		var col: Color
		if not bool(it["enabled"]):
			col = COL_DISABLED
		elif i == selected and not settings_open:
			col = COL_SEL
		else:
			col = COL_ITEM
		_center(cx, y, Lang.t(str(it["key"])), fs, col)
		y += float(fs) + (14.0 if bool(it["big"]) else 8.0)


func _center(cx: float, y: float, txt: String, size: int, col: Color) -> void:
	var font: Font = _menu_font

	if font == null:
		font = ThemeDB.fallback_font

	var w := font.get_string_size(
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size
	).x

	# yumshoq qora soya
	draw_string(
		font,
		Vector2(cx - w / 2.0 + 2.0, y + 2.0),
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		Color(0.0, 0.0, 0.0, 0.45)
	)

	# asosiy oq pixel yozuv
	draw_string(
		font,
		Vector2(cx - w / 2.0, y),
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		col
	)


# Har bandning bosiladigan sohasi
func _item_rects(vp: Vector2) -> Array:
	var font: Font = _menu_font
	if font == null:
		font = ThemeDB.fallback_font

	var cx := vp.x / 2.0
	var m := _menu_metrics(vp)
	var big: int = m[0]
	var small: int = m[1]
	var y: float = m[2]
	var out := []
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var fs: int = big if bool(it["big"]) else small
		var txt := Lang.t(str(it["key"]))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		out.append(Rect2(cx - w / 2.0 - 16.0, y - float(fs), w + 32.0, float(fs) + 8.0))
		y += float(fs) + (14.0 if bool(it["big"]) else 8.0)
	return out


func _draw_lang_badge(vp: Vector2) -> void:
	var font: Font = _menu_font
	if font == null:
		font = ThemeDB.fallback_font
	var txt := Lang.lang_display()
	var fs := 13
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_lang_badge = Rect2(16.0, vp.y - 34.0, tw + 22.0, 24.0)
	var hov: bool = _lang_badge.has_point(get_local_mouse_position())
	draw_rect(_lang_badge, Color(0.10, 0.10, 0.12, 0.9))
	draw_rect(_lang_badge, Color(0.85, 0.87, 0.85, 0.9) if hov
		else Color(0.30, 0.32, 0.34, 0.9), false, 1.0)
	draw_string(font, Vector2(_lang_badge.position.x + 11.0,
		_lang_badge.position.y + 16.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_SEL if hov else COL_ITEM)


# =========================================================================
#  BOSHQARUV
# =========================================================================
func _input(event: InputEvent) -> void:
	if _loading:
		return

	# --- Sozlamalar ochiq ---
	if settings_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if panel.escape():
					settings_open = false
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			match panel.click(event.position):
				"close":
					settings_open = false
				"quit":
					get_tree().quit()
			queue_redraw()
		elif event is InputEventMouseMotion:
			# Bosilgan holda surish — slayderlar ergashadi
			if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				panel.drag(event.position)
			queue_redraw()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				_move_selection(-1)
			KEY_DOWN, KEY_S:
				_move_selection(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate(selected)
			KEY_L:
				Lang.next_lang()
				queue_redraw()
			KEY_ESCAPE:
				if items[selected]["id"] == "exit":
					_activate(selected)
				else:
					selected = items.size() - 1
					queue_redraw()

	elif event is InputEventMouseMotion:
		var rs := _item_rects(get_viewport_rect().size)
		for i in range(rs.size()):
			if (rs[i] as Rect2).has_point(event.position):
				selected = i
				break
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _lang_badge.has_point(event.position):
			Lang.next_lang()
			queue_redraw()
			return
		var rs2 := _item_rects(get_viewport_rect().size)
		for i in range(rs2.size()):
			if (rs2[i] as Rect2).has_point(event.position):
				selected = i
				_activate(i)
				return


func _move_selection(dir: int) -> void:
	var n := items.size()
	for step in range(n):
		selected = (selected + dir + n) % n
		if bool(items[selected]["enabled"]):
			break
	queue_redraw()


func _activate(idx: int) -> void:
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	if not bool(it["enabled"]):
		_no_save_flash = 1.4
		queue_redraw()
		return

	match it["id"]:
		"play":
			# Saqlangan o'yinni davom ettiradi
			if not Lang.has_save():
				_no_save_flash = 1.4
				queue_redraw()
				return
			Lang.load_on_start = true
			_start_world()
		"new":
			Lang.load_on_start = false
			_start_world()
		"settings":
			panel.reset()
			settings_open = true
			queue_redraw()
		"exit":
			get_tree().quit()


func _start_world() -> void:
	if not ResourceLoader.exists(WORLD_SCENE):
		push_error("World sahna topilmadi: " + WORLD_SCENE)
		return
	_loading = true
	_load_frames = 0
	queue_redraw()
