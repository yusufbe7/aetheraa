extends Node
# =========================================================================
#  AETHERA — TIL va SOZLAMALAR (global singleton, autoload nomi: Lang)
#
#  Bu yerda:
#    * 3 tilga tarjima (en / ru / uz) — Lang.t("key")
#    * narsa/qurilma nomlari tarjimasi — Lang.n("Bolta")
#    * o'yin sozlamalari (til, ekran, ovoz, boshqaruv) va ularni
#      user://aethera_settings.cfg ga saqlash
#    * sahnalar orasidagi bayroqlar (menyudan "CONTINUE" bosilganmi)
#
#  MUHIM: o'yin ichidagi mantiq (inventar kalitlari, retsept nomlari)
#  HAMISHA o'zbekcha ichki nom bilan ishlaydi. Tarjima FAQAT chizishda
#  qo'llanadi — shuning uchun tilni almashtirish hech narsani buzmaydi.
# =========================================================================

signal language_changed

const CFG_PATH := "user://aethera_settings.cfg"
const SAVE_PATH := "user://aethera_save.json"

# Qo'llab-quvvatlanadigan tillar (kod -> menyuda ko'rinadigan nom)
const LANGS := [
	["en", "English"],
	["ru", "Русский"],
	["uz", "O'zbek"],
]

# ---- SOZLAMALAR ----
var lang := "en"
var fullscreen := false
var vsync := true
var shadows := false            # sukut: o'chiq (FPS uchun)
var muted := false
var control_scheme := "mouse"   # "mouse" | "wasd"

# ---- OVOZ (5 ta alohida slayder, ISO-CORE uslubida) ----
var vol_master := 0.80
var vol_music := 0.70
var vol_weather := 0.70
var vol_ambient := 0.70
var vol_sfx := 0.80

# ---- SAHNALAR ORASIDAGI BAYROQLAR ----
# Bosh menyudan CONTINUE / LOAD bosilsa true bo'ladi va main.gd
# _ready() da saqlangan o'yinni yuklaydi.
var load_on_start := false


func _ready() -> void:
	load_cfg()
	apply_video()
	apply_audio()


# =========================================================================
#  TARJIMA
# =========================================================================
func t(key: String) -> String:
	var table: Dictionary = STR.get(key, {})
	if table.is_empty():
		return key
	if table.has(lang):
		return str(table[lang])
	return str(table.get("en", key))


# Narsa / qurilma nomi (ichki nom -> tarjima). Topilmasa ichki nomni qaytaradi.
func n(internal_name: String) -> String:
	var table: Dictionary = NAMES.get(internal_name, {})
	if table.is_empty():
		return internal_name
	if table.has(lang):
		return str(table[lang])
	return str(table.get("en", internal_name))


func lang_display() -> String:
	for l in LANGS:
		if l[0] == lang:
			return str(l[1])
	return "English"


func set_lang(code: String) -> void:
	if code == lang:
		return
	lang = code
	save_cfg()
	language_changed.emit()


func next_lang() -> void:
	var idx := 0
	for i in range(LANGS.size()):
		if LANGS[i][0] == lang:
			idx = i
			break
	set_lang(str(LANGS[(idx + 1) % LANGS.size()][0]))


# =========================================================================
#  SOZLAMALARNI SAQLASH / O'QISH
# =========================================================================
func load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	lang = str(cf.get_value("general", "lang", lang))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cf.get_value("video", "vsync", vsync))
	shadows = bool(cf.get_value("video", "shadows", shadows))
	vol_master = float(cf.get_value("sound", "master", vol_master))
	vol_music = float(cf.get_value("sound", "music", vol_music))
	vol_weather = float(cf.get_value("sound", "weather", vol_weather))
	vol_ambient = float(cf.get_value("sound", "ambient", vol_ambient))
	vol_sfx = float(cf.get_value("sound", "sfx", vol_sfx))
	muted = bool(cf.get_value("sound", "muted", muted))
	control_scheme = str(cf.get_value("controls", "scheme", control_scheme))


func save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("general", "lang", lang)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "vsync", vsync)
	cf.set_value("video", "shadows", shadows)
	cf.set_value("sound", "master", vol_master)
	cf.set_value("sound", "music", vol_music)
	cf.set_value("sound", "weather", vol_weather)
	cf.set_value("sound", "ambient", vol_ambient)
	cf.set_value("sound", "sfx", vol_sfx)
	cf.set_value("sound", "muted", muted)
	cf.set_value("controls", "scheme", control_scheme)
	cf.save(CFG_PATH)


func apply_video() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func apply_audio() -> void:
	var db := -60.0 if (muted or vol_master <= 0.001) else linear_to_db(vol_master)
	AudioServer.set_bus_volume_db(0, db)
	AudioServer.set_bus_mute(0, muted)


# Slayder qiymatini nom bo'yicha o'qish/yozish (settings_panel ishlatadi)
func get_vol(id: String) -> float:
	match id:
		"master": return vol_master
		"music": return vol_music
		"weather": return vol_weather
		"ambient": return vol_ambient
		"sfx": return vol_sfx
	return 1.0


func set_vol(id: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	match id:
		"master": vol_master = v
		"music": vol_music = v
		"weather": vol_weather = v
		"ambient": vol_ambient = v
		"sfx": vol_sfx = v
	apply_audio()
	save_cfg()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# =========================================================================
#  MATNLAR
#  Har kalit: {"en": ..., "ru": ..., "uz": ...}
# =========================================================================
const STR := {
	# ---- BOSH MENYU ----
	"menu.play": {"en": "PLAY", "ru": "ИГРАТЬ", "uz": "O'YNASH"},
	"menu.new": {"en": "New World", "ru": "Новый мир", "uz": "Yangi dunyo"},
	"menu.settings": {"en": "Settings", "ru": "Настройки", "uz": "Sozlamalar"},
	"menu.exit": {"en": "Close Game", "ru": "Выйти из игры", "uz": "O'yinni yopish"},
	"menu.loading": {"en": "Loading World...", "ru": "Загрузка мира...", "uz": "Dunyo yuklanmoqda..."},
	"menu.nav_hint": {
		"en": "↑ ↓  select    •    Enter  confirm    •    Esc  back",
		"ru": "↑ ↓  выбор    •    Enter  подтвердить    •    Esc  назад",
		"uz": "↑ ↓  tanlash    •    Enter  tasdiqlash    •    Esc  ortga"},
	"menu.no_save": {
		"en": "No saved game yet",
		"ru": "Сохранений пока нет",
		"uz": "Hali saqlangan o'yin yo'q"},

	# ---- SOZLAMALAR ----
	"set.title": {"en": "SETTINGS", "ru": "НАСТРОЙКИ", "uz": "SOZLAMALAR"},
	"set.video": {"en": "Video", "ru": "Графика", "uz": "Video"},
	"set.sound": {"en": "Sound", "ru": "Звук", "uz": "Ovoz"},
	"set.controls": {"en": "Controls", "ru": "Управление", "uz": "Boshqaruv"},
	"set.language": {"en": "Language", "ru": "Язык", "uz": "Til"},
	"set.lan": {"en": "Multiplayer (LAN)", "ru": "Сетевая игра (LAN)", "uz": "Ko'p o'yinchi (LAN)"},
	"set.resume": {"en": "Resume Game", "ru": "Продолжить игру", "uz": "O'yinga qaytish"},
	"set.save": {"en": "Save Game", "ru": "Сохранить игру", "uz": "O'yinni saqlash"},
	"set.return_title": {"en": "Return To Title", "ru": "В главное меню", "uz": "Bosh menyuga"},
	"set.quit": {"en": "Quit Game", "ru": "Выйти из игры", "uz": "O'yindan chiqish"},
	"set.close": {"en": "Close", "ru": "Закрыть", "uz": "Yopish"},
	"set.back": {"en": "Back", "ru": "Назад", "uz": "Ortga"},
	"set.fullscreen": {"en": "Fullscreen", "ru": "Полный экран", "uz": "To'liq ekran"},
	"set.vsync": {"en": "VSync", "ru": "Вертикальная синхр.", "uz": "VSync"},
	"set.shadows": {"en": "Shadows", "ru": "Тени", "uz": "Soyalar"},
	"set.vol_master": {"en": "Master Volume", "ru": "Общая громкость", "uz": "Umumiy ovoz"},
	"set.vol_music": {"en": "Music", "ru": "Музыка", "uz": "Musiqa"},
	"set.vol_weather": {"en": "Weather", "ru": "Погода", "uz": "Ob-havo"},
	"set.vol_ambient": {"en": "Ambient", "ru": "Окружение", "uz": "Atrof ovozi"},
	"set.vol_sfx": {"en": "World SFX", "ru": "Звуки мира", "uz": "Dunyo ovozlari"},
	"set.close_settings": {"en": "Close Settings", "ru": "Закрыть настройки", "uz": "Sozlamalarni yopish"},
	"set.mute": {"en": "Mute", "ru": "Без звука", "uz": "Ovozsiz"},
	"set.scheme": {"en": "Movement", "ru": "Передвижение", "uz": "Yurish"},
	"set.scheme_mouse": {"en": "Mouse + WASD", "ru": "Мышь + WASD", "uz": "Sichqoncha + WASD"},
	"set.scheme_wasd": {"en": "WASD only", "ru": "Только WASD", "uz": "Faqat WASD"},
	"set.on": {"en": "ON", "ru": "ВКЛ", "uz": "YONIQ"},
	"set.off": {"en": "OFF", "ru": "ВЫКЛ", "uz": "O'CHIQ"},
	"set.host": {"en": "Host Game", "ru": "Создать игру", "uz": "O'yin ochish"},
	"set.type_ip": {"en": "Type IP", "ru": "Ввести IP", "uz": "IP yozish"},
	"set.join": {"en": "Join Game", "ru": "Подключиться", "uz": "Ulanish"},
	"set.disconnect": {"en": "Disconnect", "ru": "Отключиться", "uz": "Uzish"},
	"set.port": {"en": "Port", "ru": "Порт", "uz": "Port"},
	"set.connected": {"en": "connected", "ru": "подключено", "uz": "ulangan"},
	"set.lan_tip": {
		"en": "Host on your PC, a friend joins by your IP",
		"ru": "Создайте игру, друг подключится по вашему IP",
		"uz": "O'zingda ochasan, do'sting IP bilan ulanadi"},
	"set.typing": {"en": "<typing>", "ru": "<ввод>", "uz": "<yozilmoqda>"},
	"set.keys_hint": {
		"en": "WASD / arrows — walk   •   SHIFT — run   •   SPACE — jump\nI or TAB — inventory   •   R — use device   •   Q / E — flip, rotate\n+ / − — zoom   •   ESC — settings",
		"ru": "WASD / стрелки — идти   •   SHIFT — бежать   •   SPACE — прыжок\nI или TAB — инвентарь   •   R — устройство   •   Q / E — отразить, повернуть\n+ / − — масштаб   •   ESC — настройки",
		"uz": "WASD / strelka — yurish   •   SHIFT — yugurish   •   SPACE — sakrash\nI yoki TAB — inventar   •   R — qurilma   •   Q / E — aylantirish\n+ / − — zoom   •   ESC — sozlamalar"},

	# ---- HUD / OYNALAR ----
	"ui.inventory": {"en": "INVENTORY", "ru": "ИНВЕНТАРЬ", "uz": "INVENTAR"},
	"ui.chest": {"en": "CHEST", "ru": "СУНДУК", "uz": "SANDIQ"},
	"ui.crafting": {"en": "CRAFTING TABLE", "ru": "ВЕРСТАК", "uz": "YASASH STOLI"},
	"ui.anvil": {"en": "ANVIL", "ru": "НАКОВАЛЬНЯ", "uz": "SANDON"},
	"ui.magic": {"en": "MAGIC TABLE", "ru": "МАГИЧЕСКИЙ СТОЛ", "uz": "SEHRLI STOL"},
	"ui.craft_old": {"en": "CRAFT   (E — close)", "ru": "СОЗДАНИЕ   (E — закрыть)", "uz": "YASASH   (E — yopish)"},
	"ui.drag_hint": {
		"en": "Drag an item into the first row (hotbar)",
		"ru": "Перетащите предмет в первый ряд (панель)",
		"uz": "Narsani birinchi qatorga (hotbar) sudrab qo'y"},
	"ui.chest_hint": {
		"en": "Click to move items  •  R or E to close",
		"ru": "Клик — переместить  •  R или E — закрыть",
		"uz": "Bosib ko'chirasan  •  R yoki E — yopish"},
	"ui.got_it": {"en": "Got It!", "ru": "Понятно!", "uz": "Tushundim!"},
	"ui.for_tree": {"en": "for trees", "ru": "для деревьев", "uz": "daraxt uchun"},
	"ui.for_rock": {"en": "for rocks", "ru": "для камня", "uz": "tosh uchun"},
	"ui.tree_x2": {"en": "(trees x2)", "ru": "(дерево x2)", "uz": "(daraxt x2)"},
	"ui.rock_x2": {"en": "(rocks x2)", "ru": "(камень x2)", "uz": "(tosh x2)"},

	# ---- OGOHLANTIRISHLAR ----
	"hint.cant_reach": {"en": "Can't reach", "ru": "Не достать", "uz": "Yetib bo'lmaydi"},
	"hint.chest_full": {"en": "Chest full", "ru": "Сундук полон", "uz": "Sandiq to'la"},
	"hint.inv_full": {"en": "Inventory full", "ru": "Инвентарь полон", "uz": "Inventar to'la"},
	"hint.empty_chest": {"en": "Empty the chest first", "ru": "Сначала опустошите сундук", "uz": "Avval sandiqni bo'shat"},
	"hint.not_ripe": {"en": "Not ripe yet", "ru": "Ещё не созрело", "uz": "Hali pishmagan"},
	"hint.ground": {
		"en": "Ground: SHOVEL -> water, PICKAXE -> soil",
		"ru": "Земля: ЛОПАТА -> вода, КИРКА -> почва",
		"uz": "Yer: BELKURAK -> suv, KIRKA -> tuproq"},
	"hint.facing": {"en": "Facing", "ru": "Направление", "uz": "Yo'nalish"},
	"hint.left": {"en": "left", "ru": "влево", "uz": "chapga"},
	"hint.right": {"en": "right", "ru": "вправо", "uz": "o'ngga"},
	"hint.saved": {"en": "Game saved", "ru": "Игра сохранена", "uz": "O'yin saqlandi"},
	"hint.loaded": {"en": "Game loaded", "ru": "Игра загружена", "uz": "O'yin yuklandi"},
	"hint.save_failed": {"en": "Save failed", "ru": "Не удалось сохранить", "uz": "Saqlab bo'lmadi"},
	"hint.world_synced": {"en": "World synced", "ru": "Мир синхронизирован", "uz": "Dunyo sinxronlandi"},
	"hint.player_joined": {"en": "Player joined", "ru": "Игрок подключился", "uz": "O'yinchi ulandi"},
	"hint.player_left": {"en": "Player left", "ru": "Игрок вышел", "uz": "O'yinchi chiqdi"},
	"hint.connect_failed": {"en": "Could not connect", "ru": "Не удалось подключиться", "uz": "Ulanib bo'lmadi"},
	"hint.server_closed": {"en": "Server closed", "ru": "Сервер закрыт", "uz": "Server yopildi"},
	"hint.host_opened": {"en": "Host opened. Port:", "ru": "Игра создана. Порт:", "uz": "Host ochildi. Port:"},
	"hint.need_axe": {
		"en": "cannot cut a tree — use your hands or an Axe",
		"ru": "не срубит дерево — нужны руки или Топор",
		"uz": "bilan daraxt kesilmaydi — qo'l yoki Bolta kerak"},
	"hint.need_pick": {
		"en": "cannot break stone — use your hands or a Pickaxe",
		"ru": "не разобьёт камень — нужны руки или Кирка",
		"uz": "bilan tosh sindirilmaydi — qo'l yoki Kirka kerak"},
	"hint.need_shovel": {
		"en": "You need a SHOVEL to dig",
		"ru": "Чтобы копать, нужна ЛОПАТА",
		"uz": "Yerni qazish uchun BELKURAK kerak"},

	# ---- TUTORIAL ----
	"tut.move.t": {"en": "Move", "ru": "Движение", "uz": "Yurish"},
	"tut.move.b": {
		"en": "Use W A S D or the arrow keys to walk. Your character runs — hold SHIFT to go even faster.",
		"ru": "Идите с помощью W A S D или стрелок. Персонаж бежит — удерживайте SHIFT, чтобы ускориться.",
		"uz": "W A S D yoki strelkalar bilan yur. Personaj yuguradi — SHIFT bilan yanada tezroq."},
	"tut.click.t": {"en": "Click to walk", "ru": "Клик для ходьбы", "uz": "Bosib yurish"},
	"tut.click.b": {
		"en": "Left-click a ground cell and your character will walk there on its own.",
		"ru": "Щёлкните левой кнопкой по клетке — персонаж сам туда дойдёт.",
		"uz": "Yer katagini chap tugma bilan bos — personaj o'zi boradi."},
	"tut.chop.t": {"en": "Chop", "ru": "Рубка", "uz": "Kesish"},
	"tut.chop.b": {
		"en": "Left-click a tree or rock — your character walks over and chops it automatically. Wood and stone are collected for you.",
		"ru": "Щёлкните по дереву или камню — персонаж подойдёт и сам добудет. Дерево и камень соберутся сами.",
		"uz": "Daraxt yoki toshni bos — personaj borib o'zi chopadi. Yog'och va tosh o'zi yig'iladi."},
	"tut.inv.t": {"en": "Inventory", "ru": "Инвентарь", "uz": "Inventar"},
	"tut.inv.b": {
		"en": "Press I or TAB (or E when your hands are free) any time to open the inventory. Drag items into the hotbar at the bottom.",
		"ru": "Нажмите I или TAB (либо E со свободными руками), чтобы открыть инвентарь. Перетащите предметы на нижнюю панель.",
		"uz": "Istalgan payt I yoki TAB (qo'l bo'sh bo'lsa E) bosib inventarni och. Narsalarni pastdagi hotbarga sudrab qo'y."},
	"tut.build.t": {"en": "Build", "ru": "Постройка", "uz": "Qurish"},
	"tut.build.b": {
		"en": "Pick a device from the hotbar, then RIGHT-click the ground to place it. Q flips left/right, E rotates 90 degrees.",
		"ru": "Выберите устройство на панели и щёлкните ПРАВОЙ кнопкой по земле. Q отражает, E поворачивает на 90°.",
		"uz": "Hotbardan qurilmani tanla, so'ng yerni O'NG tugma bilan bos. Q — chap/o'ng, E — 90 daraja aylantiradi."},
	"tut.dev.t": {"en": "Devices", "ru": "Устройства", "uz": "Qurilmalar"},
	"tut.dev.b": {
		"en": "Walk up to a Workbench, Magic Table, Anvil or Chest and press R to open its window.",
		"ru": "Подойдите к Верстаку, Магическому столу, Наковальне или Сундуку и нажмите R.",
		"uz": "Yasash stoli, Sehrli stol, Sandon yoki Sandiq yoniga borib R ni bos."},
	"tut.zoom.t": {"en": "Jump & zoom", "ru": "Прыжок и масштаб", "uz": "Sakrash va zoom"},
	"tut.zoom.b": {
		"en": "Press SPACE to jump. Use the + and - keys to zoom the view in and out.",
		"ru": "Нажмите SPACE для прыжка. Клавишами + и - меняйте масштаб.",
		"uz": "SPACE bilan sakra. + va - tugmalari bilan ko'rinishni kattalashtir/kichraytir."},
}


# =========================================================================
#  NARSA / QURILMA NOMLARI
#  Kalit — o'yin ichidagi ICHKI nom (o'zgartirilmaydi!)
# =========================================================================
const NAMES := {
	# resurslar
	"Yog'och": {"en": "Wood", "ru": "Дерево", "uz": "Yog'och"},
	"Palma yog'ochi": {"en": "Palm Wood", "ru": "Пальмовое дерево", "uz": "Palma yog'ochi"},
	"Kaktus": {"en": "Cactus", "ru": "Кактус", "uz": "Kaktus"},
	"Tosh": {"en": "Stone", "ru": "Камень", "uz": "Tosh"},
	"O't": {"en": "Grass", "ru": "Трава", "uz": "O't"},
	"Oltin": {"en": "Gold", "ru": "Золото", "uz": "Oltin"},
	"Safir": {"en": "Sapphire", "ru": "Сапфир", "uz": "Safir"},
	"Mis": {"en": "Copper", "ru": "Медь", "uz": "Mis"},
	"Bug'doy": {"en": "Wheat", "ru": "Пшеница", "uz": "Bug'doy"},
	"Urug'": {"en": "Seeds", "ru": "Семена", "uz": "Urug'"},
	# asboblar
	"Bolta": {"en": "Axe", "ru": "Топор", "uz": "Bolta"},
	"Kirka": {"en": "Pickaxe", "ru": "Кирка", "uz": "Kirka"},
	"Qilich": {"en": "Sword", "ru": "Меч", "uz": "Qilich"},
	"Belkurak": {"en": "Shovel", "ru": "Лопата", "uz": "Belkurak"},
	"Mash'al": {"en": "Torch", "ru": "Факел", "uz": "Mash'al"},
	"Kamon": {"en": "Bow", "ru": "Лук", "uz": "Kamon"},
	"Qarmoq": {"en": "Fishing Rod", "ru": "Удочка", "uz": "Qarmoq"},
	# qurilmalar
	"Yasash stoli": {"en": "Workbench", "ru": "Верстак", "uz": "Yasash stoli"},
	"Anvil": {"en": "Anvil", "ru": "Наковальня", "uz": "Sandon"},
	"Furnace": {"en": "Furnace", "ru": "Печь", "uz": "O'choq"},
	"Ko'ra": {"en": "Kiln", "ru": "Горн", "uz": "Ko'ra"},
	"Windmill": {"en": "Windmill", "ru": "Ветряная мельница", "uz": "Shamol tegirmoni"},
	"MagicTable": {"en": "Magic Table", "ru": "Магический стол", "uz": "Sehrli stol"},
	"Sandiq": {"en": "Chest", "ru": "Сундук", "uz": "Sandiq"},
	"To'siq": {"en": "Fence", "ru": "Забор", "uz": "To'siq"},
	"Ko'prik": {"en": "Bridge", "ru": "Мост", "uz": "Ko'prik"},
	"Yo'lak": {"en": "Path", "ru": "Дорожка", "uz": "Yo'lak"},
	"Tosh maydon": {"en": "Stone Plaza", "ru": "Каменная площадка", "uz": "Tosh maydon"},
	"Organ": {"en": "Organ", "ru": "Орган", "uz": "Organ"},
	"Qozon": {"en": "Cauldron", "ru": "Котёл", "uz": "Qozon"},
	"Yog'och ustun": {"en": "Wood Post", "ru": "Деревянный столб", "uz": "Yog'och ustun"},
	"Kristall ustun": {"en": "Crystal Pillar", "ru": "Кристальная колонна", "uz": "Kristall ustun"},
	"Sehrli kristall": {"en": "Magic Crystal", "ru": "Магический кристалл", "uz": "Sehrli kristall"},
	"Kristall blok": {"en": "Crystal Block", "ru": "Кристальный блок", "uz": "Kristall blok"},
}
