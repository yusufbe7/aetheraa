class_name SettingsPanel
extends RefCounted
# =========================================================================
#  AETHERA — SOZLAMALAR (bosh menyu VA o'yin ichida bir xil ko'rinish)
#
#  Dizayn: ISO-CORE uslubi — fon qoraytiriladi, matnlar EKRAN MARKAZIDA,
#  ichki sahifalar sarlavhasi kichik harflar bilan ("sound", "controls"),
#  chapda yozuv — o'ngda slayder / tanlash oynasi.
#
#  Ishlatilishi:
#      var panel := SettingsPanel.new()
#      panel.in_game = true
#      panel.draw_panel(self, vp, mouse, world_or_null)
#      var act := panel.click(mouse)   # "" = ichida hal bo'ldi
#
#  Qiymatlar Lang (autoload) da — user://aethera_settings.cfg ga saqlanadi.
# =========================================================================

const C_DIM := Color(0.02, 0.03, 0.04, 0.62)
const C_TITLE := Color(0.96, 0.97, 0.94)
const C_TEXT := Color(0.88, 0.90, 0.88)
const C_TEXT_DIM := Color(0.62, 0.66, 0.64)
const C_HOVER := Color(1.0, 1.0, 1.0)
const C_SHADOW := Color(0.0, 0.0, 0.0, 0.65)
const C_BOX := Color(0.13, 0.20, 0.13, 0.85)
const C_BOX_EDGE := Color(0.34, 0.45, 0.32, 0.85)
const C_BOX_EDGE_HOV := Color(0.62, 0.76, 0.56, 0.95)
const C_SLIDER_BG := Color(0.10, 0.12, 0.10, 0.90)
const C_SLIDER_FILL := Color(0.86, 0.90, 0.86, 0.95)
const C_KNOB := Color(0.95, 0.97, 0.94)
const C_CHECK := Color(0.65, 0.90, 0.60)

const ROW_H := 30.0
const SLIDER_W := 150.0
const BOX_W := 132.0
const BOX_H := 26.0

var page := "main"        # main / video / sound / controls / language / lan
var in_game := false
var dropdown := ""        # "" | "scheme" | "lang"
var rects := []           # [{rect, action, kind, id}]
var typing_ip := false


func reset() -> void:
	page = "main"
	dropdown = ""


# =========================================================================
#  CHIZISH
# =========================================================================
func draw_panel(ci: CanvasItem, vp: Vector2, mouse: Vector2, world = null) -> void:
	rects = []
	ci.draw_rect(Rect2(Vector2.ZERO, vp), C_DIM)
	if page == "main":
		_draw_main(ci, vp, mouse, world)
	else:
		_draw_sub(ci, vp, mouse, world)


# ---- ASOSIY SAHIFA: markazda ro'yxat ----
func _draw_main(ci: CanvasItem, vp: Vector2, mouse: Vector2, world) -> void:
	var cx: float = vp.x / 2.0
	var items := []
	if in_game:
		items.append([Lang.t("set.resume"), "close"])
		items.append([Lang.t("set.save"), "save_game"])
	items.append([Lang.t("set.video"), "page_video"])
	items.append([Lang.t("set.sound"), "page_sound"])
	items.append([Lang.t("set.controls"), "page_controls"])
	items.append([Lang.t("set.language"), "page_language"])
	if world != null:
		items.append([Lang.t("set.lan"), "page_lan"])
	if in_game:
		items.append([Lang.t("set.return_title"), "return_title"])
	items.append([Lang.t("set.quit"), "quit"])

	# Balandlikni hisoblab, blokni markazga qo'yamiz
	var total: float = 44.0 + float(items.size()) * 22.0 + 34.0
	var y: float = (vp.y - total) / 2.0 + 26.0

	_center_text(ci, cx, y, Lang.t("set.title"), 26, C_TITLE)
	y += 44.0

	for it in items:
		y = _center_item(ci, cx, y, str(it[0]), str(it[1]), mouse, 15)

	# "Close Settings" — bo'sh joydan keyin
	y += 12.0
	_center_item(ci, cx, y, Lang.t("set.close_settings"), "close", mouse, 15)


# ---- ICHKI SAHIFALAR: kichik sarlavha + chap yozuv / o'ng boshqaruv ----
func _draw_sub(ci: CanvasItem, vp: Vector2, mouse: Vector2, world) -> void:
	var cx: float = vp.x / 2.0
	var rows := _sub_rows(world)
	var drop_h: float = 0.0
	if dropdown != "":
		drop_h = float(_dropdown_options().size()) * BOX_H
	var total: float = 52.0 + float(rows.size()) * ROW_H + drop_h + 52.0
	var y: float = (vp.y - total) / 2.0 + 24.0

	_center_text(ci, cx, y, _page_title(), 24, C_TITLE)
	y += 52.0

	for r in rows:
		var kind := str(r["kind"])
		var label := str(r["label"])
		match kind:
			"info":
				_center_text(ci, cx, y + 18.0, label, 13, C_TEXT_DIM)
				y += ROW_H
			"slider":
				_row_label(ci, cx - 22.0, y, label)
				var sx: float = cx - 6.0
				var val: float = Lang.get_vol(str(r["id"]))
				_slider(ci, sx, y + BOX_H / 2.0, val)
				rects.append({"rect": Rect2(sx - 6.0, y, SLIDER_W + 12.0, BOX_H),
					"action": "vol", "id": str(r["id"]), "sx": sx})
				y += ROW_H
			"toggle":
				_row_label(ci, cx - 22.0, y, label)
				var on: bool = bool(r["value"])
				var box := Rect2(cx - 6.0, y, BOX_W, BOX_H)
				var hov: bool = box.has_point(mouse)
				_box(ci, box, hov)
				var vtxt: String = Lang.t("set.on") if on else Lang.t("set.off")
				ci.draw_string(ThemeDB.fallback_font,
					Vector2(box.position.x + 10.0, y + 18.0), vtxt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
					C_CHECK if on else C_TEXT_DIM)
				rects.append({"rect": box, "action": str(r["action"]), "id": ""})
				y += ROW_H
			"select":
				_row_label(ci, cx - 22.0, y, label)
				var box2 := Rect2(cx - 6.0, y, BOX_W, BOX_H)
				var hov2: bool = box2.has_point(mouse)
				_box(ci, box2, hov2)
				ci.draw_string(ThemeDB.fallback_font,
					Vector2(box2.position.x + 10.0, y + 18.0), str(r["value"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_TEXT)
				# O'ngdagi pastga strelka
				var ax: float = box2.end.x - 16.0
				var ay: float = y + BOX_H / 2.0 - 1.0
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(ax - 5.0, ay - 2.0), Vector2(ax + 5.0, ay - 2.0),
					Vector2(ax, ay + 4.0)]), Color(0.72, 0.82, 0.70))
				rects.append({"rect": box2, "action": str(r["action"]), "id": ""})
				y += ROW_H
				# Ochilgan ro'yxat
				if dropdown != "" and str(r["action"]) == "open_" + dropdown:
					var opts := _dropdown_options()
					ci.draw_rect(Rect2(box2.position.x, y, BOX_W,
						BOX_H * float(opts.size())), Color(0.10, 0.16, 0.10, 0.92))
					for o in opts:
						var orect := Rect2(box2.position.x, y, BOX_W, BOX_H)
						var ohov: bool = orect.has_point(mouse)
						if ohov:
							ci.draw_rect(orect, Color(0.20, 0.30, 0.18, 0.95))
						ci.draw_rect(orect, Color(0.34, 0.45, 0.32, 0.55), false, 1.0)
						if bool(o[2]):
							ci.draw_string(ThemeDB.fallback_font,
								Vector2(orect.position.x + 8.0, y + 18.0), "✓",
								HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_CHECK)
						ci.draw_string(ThemeDB.fallback_font,
							Vector2(orect.position.x + 26.0, y + 18.0), str(o[0]),
							HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
							C_HOVER if ohov else C_TEXT)
						rects.append({"rect": orect, "action": str(o[1]), "id": ""})
						y += BOX_H
			"btn":
				_center_item(ci, cx, y + 4.0, label, str(r["action"]), mouse, 15)
				y += ROW_H

	# "Close" — pastda markazda
	y += 26.0
	_center_item(ci, cx, y, Lang.t("set.close"), "back", mouse, 16)


func _sub_rows(world) -> Array:
	var rows := []
	match page:
		"video":
			rows.append({"kind": "toggle", "label": Lang.t("set.fullscreen"),
				"action": "toggle_fullscreen", "value": Lang.fullscreen, "id": ""})
			rows.append({"kind": "toggle", "label": Lang.t("set.vsync"),
				"action": "toggle_vsync", "value": Lang.vsync, "id": ""})
			rows.append({"kind": "toggle", "label": Lang.t("set.shadows"),
				"action": "toggle_shadows", "value": Lang.shadows, "id": ""})
		"sound":
			rows.append({"kind": "slider", "label": Lang.t("set.vol_master"), "id": "master", "action": "vol", "value": 0})
			rows.append({"kind": "slider", "label": Lang.t("set.vol_music"), "id": "music", "action": "vol", "value": 0})
			rows.append({"kind": "slider", "label": Lang.t("set.vol_weather"), "id": "weather", "action": "vol", "value": 0})
			rows.append({"kind": "slider", "label": Lang.t("set.vol_ambient"), "id": "ambient", "action": "vol", "value": 0})
			rows.append({"kind": "slider", "label": Lang.t("set.vol_sfx"), "id": "sfx", "action": "vol", "value": 0})
			rows.append({"kind": "toggle", "label": Lang.t("set.mute"),
				"action": "toggle_mute", "value": Lang.muted, "id": ""})
		"controls":
			rows.append({"kind": "select", "label": Lang.t("set.controls"),
				"action": "open_scheme", "value": _scheme_name(), "id": ""})
			for line in Lang.t("set.keys_hint").split("\n"):
				rows.append({"kind": "info", "label": line, "action": "", "id": ""})
		"language":
			rows.append({"kind": "select", "label": Lang.t("set.language"),
				"action": "open_lang", "value": Lang.lang_display(), "id": ""})
		"lan":
			if world != null and bool(world.net_active):
				rows.append({"kind": "info", "action": "", "id": "",
					"label": ("HOST" if bool(world.net_is_host) else "CLIENT")
						+ "  —  " + Lang.t("set.connected") + ": "
						+ str(world.net_peers.size())})
				rows.append({"kind": "info", "action": "", "id": "",
					"label": Lang.t("set.port") + ": " + str(world.NET_PORT)})
				rows.append({"kind": "btn", "label": Lang.t("set.disconnect"),
					"action": "net_off", "id": ""})
			elif world != null:
				rows.append({"kind": "info", "label": Lang.t("set.lan_tip"),
					"action": "", "id": ""})
				rows.append({"kind": "info", "action": "", "id": "",
					"label": "IP: " + str(world.join_ip)
						+ ("   " + Lang.t("set.typing") if typing_ip else "")})
				rows.append({"kind": "btn", "label": Lang.t("set.host"),
					"action": "net_host", "id": ""})
				rows.append({"kind": "btn", "label": Lang.t("set.type_ip"),
					"action": "type_ip", "id": ""})
				rows.append({"kind": "btn", "label": Lang.t("set.join"),
					"action": "net_join", "id": ""})
	return rows


func _page_title() -> String:
	match page:
		"video": return Lang.t("set.video").to_lower()
		"sound": return Lang.t("set.sound").to_lower()
		"controls": return Lang.t("set.controls").to_lower()
		"language": return Lang.t("set.language").to_lower()
		"lan": return Lang.t("set.lan").to_lower()
	return Lang.t("set.title")


func _scheme_name() -> String:
	return "Mouse" if Lang.control_scheme == "mouse" else "WASD"


func _dropdown_options() -> Array:
	match dropdown:
		"scheme":
			return [
				["Mouse", "scheme_mouse", Lang.control_scheme == "mouse"],
				["WASD", "scheme_wasd", Lang.control_scheme == "wasd"],
			]
		"lang":
			var out := []
			for l in Lang.LANGS:
				out.append([str(l[1]), "lang_" + str(l[0]), Lang.lang == str(l[0])])
			return out
	return []


# =========================================================================
#  BOSISH
# =========================================================================
func click(pos: Vector2) -> String:
	for it in rects:
		if not (it["rect"] as Rect2).has_point(pos):
			continue
		if str(it["action"]) == "vol":
			var sx: float = float(it["sx"])
			Lang.set_vol(str(it["id"]), (pos.x - sx) / SLIDER_W)
			return "volumes"
		return _do(str(it["action"]))
	return ""


# Sichqoncha bosilgan holda surилsa — slayder ergashadi
func drag(pos: Vector2) -> String:
	for it in rects:
		if str(it["action"]) != "vol":
			continue
		if not (it["rect"] as Rect2).has_point(pos):
			continue
		Lang.set_vol(str(it["id"]), (pos.x - float(it["sx"])) / SLIDER_W)
		return "volumes"
	return ""


func _do(act: String) -> String:
	match act:
		"page_video":
			page = "video"; dropdown = ""; return ""
		"page_sound":
			page = "sound"; dropdown = ""; return ""
		"page_controls":
			page = "controls"; dropdown = ""; return ""
		"page_language":
			page = "language"; dropdown = ""; return ""
		"page_lan":
			page = "lan"; dropdown = ""; return ""
		"back":
			if dropdown != "":
				dropdown = ""
			else:
				page = "main"
			return ""
		"open_scheme":
			dropdown = "" if dropdown == "scheme" else "scheme"; return ""
		"open_lang":
			dropdown = "" if dropdown == "lang" else "lang"; return ""
		"scheme_mouse":
			Lang.control_scheme = "mouse"; dropdown = ""; Lang.save_cfg(); return ""
		"scheme_wasd":
			Lang.control_scheme = "wasd"; dropdown = ""; Lang.save_cfg(); return ""
		"toggle_fullscreen":
			Lang.fullscreen = not Lang.fullscreen
			Lang.apply_video(); Lang.save_cfg(); return ""
		"toggle_vsync":
			Lang.vsync = not Lang.vsync
			Lang.apply_video(); Lang.save_cfg(); return ""
		"toggle_shadows":
			Lang.shadows = not Lang.shadows; Lang.save_cfg(); return ""
		"toggle_mute":
			Lang.muted = not Lang.muted
			Lang.apply_audio(); Lang.save_cfg(); return "volumes"
		"type_ip":
			typing_ip = not typing_ip
			return "type_ip"
	if act.begins_with("lang_"):
		Lang.set_lang(act.substr(5))
		dropdown = ""
		return ""
	# Qolganini caller bajaradi: close / quit / return_title / save_game /
	# net_host / net_join / net_off
	return act


# ESC: ichki sahifadan ortga, "main" da esa yopiladi (true = yopilsin)
func escape() -> bool:
	if dropdown != "":
		dropdown = ""
		return false
	if page != "main":
		page = "main"
		return false
	return true


# =========================================================================
#  YORDAMCHILAR
# =========================================================================
func _center_text(ci: CanvasItem, cx: float, y: float, txt: String,
		size: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(cx - w / 2.0 + 2.0, y + 2.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, C_SHADOW)
	ci.draw_string(font, Vector2(cx - w / 2.0, y), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# Markazdagi bosiladigan band. Yangi y ni qaytaradi.
func _center_item(ci: CanvasItem, cx: float, y: float, txt: String,
		action: String, mouse: Vector2, size: int) -> float:
	var font: Font = ThemeDB.fallback_font
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var rect := Rect2(cx - w / 2.0 - 14.0, y - float(size), w + 28.0, float(size) + 10.0)
	var hov: bool = rect.has_point(mouse)
	ci.draw_string(font, Vector2(cx - w / 2.0 + 1.0, y + 1.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, C_SHADOW)
	ci.draw_string(font, Vector2(cx - w / 2.0, y), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, C_HOVER if hov else C_TEXT)
	rects.append({"rect": rect, "action": action, "id": ""})
	return y + 22.0


# O'ng chetiga tekislangan yozuv (boshqaruv elementi chapidagi nom)
func _row_label(ci: CanvasItem, right_x: float, y: float, txt: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	ci.draw_string(font, Vector2(right_x - w + 1.0, y + 19.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_SHADOW)
	ci.draw_string(font, Vector2(right_x - w, y + 18.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_TEXT)


func _box(ci: CanvasItem, rect: Rect2, hovered: bool) -> void:
	ci.draw_rect(rect, C_BOX)
	ci.draw_rect(rect, C_BOX_EDGE_HOV if hovered else C_BOX_EDGE, false, 1.0)


func _slider(ci: CanvasItem, x: float, cy: float, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	# Yo'lak
	ci.draw_rect(Rect2(x, cy - 3.0, SLIDER_W, 6.0), C_SLIDER_BG)
	ci.draw_rect(Rect2(x, cy - 3.0, SLIDER_W * v, 6.0), C_SLIDER_FILL)
	# Tutqich
	var hx: float = x + SLIDER_W * v
	ci.draw_rect(Rect2(hx - 5.0, cy - 8.0, 10.0, 16.0), C_KNOB)
	ci.draw_rect(Rect2(hx - 5.0, cy - 8.0, 10.0, 16.0),
		Color(0.20, 0.24, 0.20, 0.9), false, 1.0)
