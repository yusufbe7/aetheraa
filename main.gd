class_name AetheraWorld
extends Node2D

# =========================================================================
#  AETHERA — Procgen dunyo + O'yinchi + Chopish + Animatsiyali daraxt
#  + DEPTH SORTING (personaj daraxt orqasiga o'tsa to'siladi)
# =========================================================================

const TILE_W := 32.0
const TILE_H := 16.0

# Oq kontur (outline) uchun — rasmni 8 tomonga 1px surib chizamiz
const OUTLINE_OFFSETS := [
	Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
	Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1),
]

const ASSET_DIR := "res://assets/"

# ---- YER TAYLLARI ----
# Butun quruqlik BITTA yashil tayl bilan (ISO-CORE kabi bir xil yashil).
# Boshqa yashilga almashtirmoqchi bo'lsang, quyidagi nomni o'zgartir:
#   "tile_022" (ochroq) / "tile_024" (o'rtacha) / "tile_040" (to'qroq)
# 2D world skripti uchun yer teksturasi PNG bo‘lishi kerak.
# Blender modeli (.blend) bu skript orqali Texture2D sifatida chizilmaydi.
# Hozircha mavjud ISO yer teksturasidan foydalanamiz.
const LAND_TILE := "tile_040"
# Foydalanuvchi bergan qum blokidan 32x32 ISO tile.
const SAND_TILE := "tile_sand"

# Blender modeli keyingi 3D versiya uchun saqlanadi:
const BLENDER_LAND_SCENE := "res://assets/blender/bloc.blend"

# =========================================================================
#  SUV CHETLARI (auto-tiling)
#  Har suv katagining 4 qo'shnisi tekshiriladi. Qaysi tomonda QURUQLIK
#  bo'lsa, o'sha chetida oq ko'pik bo'lgan tayl qo'yiladi.
#
#  Izometrik yo'nalishlar (grid_to_local dan):
#    NW = (col-1, row)   NE = (col, row-1)
#    SE = (col+1, row)   SW = (col, row+1)
#
#  Bit maskasi: NW=1, NE=2, SE=4, SW=8
#  Tayllar PNG tahlilidan aniqlangan (qaysi chetda ko'pik bor).
# =========================================================================
const WATER_NW := 1
const WATER_NE := 2
const WATER_SE := 4
const WATER_SW := 8

var WATER_TILES := {
	0:  "tile_104",   # toza suv — atrofi ham suv
	2:  "tile_105",   # NE
	1:  "tile_106",   # NW
	4:  "tile_107",   # SE
	8:  "tile_108",   # SW
	3:  "tile_109",   # NW + NE  (tepa burchak)
	12: "tile_110",   # SW + SE  (past burchak)
	9:  "tile_111",   # NW + SW  (chap burchak)
	6:  "tile_112",   # NE + SE  (o'ng burchak)
	15: "tile_113",   # to'rt tomoni ham quruqlik
}
# Uch tomonli va qarama-qarshi juftliklar uchun eng yaqin mos tayl
const WATER_FALLBACK := "tile_113"


# Biome tilelari: suv + qum + yashil.
var GROUND := {
	"water":   ["tile_104"],
	"sand":    [SAND_TILE],
	"dirt":    [LAND_TILE],
	"grass":   [LAND_TILE],      # o'rmon / o'tloq
	"savanna": [LAND_TILE],      # quruq yaylov (o'rmon -> cho'l o'tishi)
	"steppe":  [LAND_TILE],      # toshli dasht (o'tish)
	"tundra":  ["tile_snow"],    # sovuq tundra (qor atrofi)
	"snow":    ["tile_snow"],
}

# FLOWER ataylab olib tashlandi.
# Endi tile_053/055/056/057 umuman spawn qilinmaydi.
var DECOR := {
	"plant": ["tile_041", "tile_042", "tile_043", "tile_044"],
}

# ---- YANGI TOSHLAR (rock papkasidan) ----
const ROCK_DIR := "res://assets/rocks/"
# [fayl nomi, kadr eni, kadr balandligi]
var ROCK_DEFS := [
	# Faqat bitta tosh: res://assets/rocks/rock_01.png
	# O'lchami kod tomonidan PNG ichidan avtomatik olinadi.
	["rock_01"],
]
var _rock_data := []

const TREE_DIR := "res://assets/trees/"
const TREE_FPS := 8.0

# Oddiy daraxtlarning o'yindagi maksimal ko'rinadigan balandligi.
const TREE_MAX_HEIGHT := 76.0

# Rare daraxtni oddiy daraxtlardan ajratib turamiz.
# Oxirgi element DOIMO rare daraxt bo'lishi kerak.
const RARE_TREE_CHANCE := 0.015 # 1.5% — faqat kamdan-kam chiqadigan daraxt

# Har daraxt: [nom, o'yindagi maksimal balandlik]
# O'lcham PNG dan avtomatik olinadi (atrofidagi shaffof joy kesiladi),
# shuning uchun barcha daraxtlar bir xil masshtabda ko'rinadi.
var TREE_DEFS := [
	["tree_03",   76.0],  # sariq kuzgi daraxt   (yashil biome)
	["tree_08",   76.0],  # yashil ignabargli    (yashil biome)
	["tree_rare", 76.0],  # kamyob kuzgi daraxt  (yashil biome)
	["tree_05",   40.0],  # KAKTUS — pastroq, daraxtlardan kichik (qum biome)
	["tree_09",   70.0],  # PALMA                (qum biome)
	["tree_snow1", 76.0], # QORLI ARCHA 1        (qor biome)
	["tree_snow2", 76.0], # QORLI ARCHA 2        (qor biome)
]
var _tree_data := []

# ---- STUMP (kesilgan daraxt kundasi) ----
# Daraxt kesilgach, o'sha katakda kunda qoladi.
const STUMP_PATH := "res://assets/trees/stump.png"
# ---- O'T (grass tuft) — bir urishda kesiladi, tile_043 item beradi ----
const GRASS_BLOCK_PATH := "res://assets/objects/grass_block.png"
const GRASS_MAX_HEIGHT := 22.0
# ---- BUG'DOY (ekin) sprite'lari: 4 bosqich ----
const WHEAT_DIR := "res://assets/objects/"
const WHEAT_MAX_HEIGHT := 44.0
var wheat_textures := []          # [stage0..stage3] Texture2D
var grass_texture: Texture2D = null
var grass_white: Texture2D = null
const STUMP_MAX_HEIGHT := 22.0
var stump_texture: Texture2D = null
var stump_white: Texture2D = null

var tree_anim_frame := 0
var _anim_timer := 0.0

# ---- O'TIN (yog'och resursi) ----
# item.zip ichidagi ikkita kichik log rasmini drop sifatida ishlatamiz.
# Har daraxt turi O'Z itemini beradi va inventarda ALOHIDA to'planadi.
const WOOD_DROP_PATH   := "res://assets/trees/tree_07.png"  # oddiy daraxt -> Yog'och
const PALM_DROP_PATH   := "res://assets/trees/tree_01.png"  # palma       -> Palma yog'ochi
const CACTUS_DROP_PATH := "res://assets/trees/tree_06.png"  # kaktus      -> Kaktus

var _wood_drop_texture: Texture2D = null
var _palm_drop_texture: Texture2D = null
var _cactus_drop_texture: Texture2D = null

# drop turi -> [item nomi, ikonka kaliti]
const DROP_ITEMS := {
	"wood":   ["Yog'och",        "item_wood"],
	"palm":   ["Palma yog'ochi", "item_palm"],
	"cactus": ["Kaktus",         "item_cactus"],
	"stone":  ["Tosh",           "silver_ore"],
	"stump_wood": ["Yog'och",    "item_wood"],
	"grass":  ["O't",            "item_grass"],
	"gold":   ["Oltin",          "gold_ore"],
	"gem":    ["Safir",          "sapphire"],
}

# Tosh sindirilganda ma'dan chiqish ehtimoli (har bo'lak uchun)
const GOLD_CHANCE := 0.16    # 16% oltin
const GEM_CHANCE := 0.07     # 7% safir

# Yerda uchib-sakrab yurgan o'tinlar (har biri alohida fizika bilan)
# Har biri: {pos, vel, z, zvel, variant, born, state, kind}
# state: "fly" -> "settle" -> "to_player"
var wood_items := []
# Yig'ilgan resurslar
var wood_count := 0
var stone_count := 0

var _tex_cache := {}

var height_noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()   # HARORAT
var humid_noise := FastNoiseLite.new()   # NAMLIK
var decor_noise := FastNoiseLite.new()
var elev_noise := FastNoiseLite.new()    # YER BALANDLIGI (terrasa darajalari)
const WORLD_SEED := 1337

# =========================================================================
#  YER BALANDLIGI (TERRASA) — 4-rasmdagi Minecraft uslubi
#  ELEVATION_ENABLED = false qilsangiz hamma narsa AVVALGIDEK tekis bo'ladi
#  (ya'ni bu tizim biror joyni buzsa, darhol o'chirib qo'yish mumkin).
# =========================================================================
# HOZIRCHA O'CHIQ (terrasa "yoriqlari" g'alati edi). Yangi bloklar
# tayyor bo'lgach qayta TRUE qilamiz.
const ELEVATION_ENABLED := false
const ELEV_LEVELS := 3           # eng baland daraja (0..3)
const LEVEL_LIFT := 11.0         # har daraja necha px yuqoriga ko'tariladi (ekranda)
var _elev_cache := {}

var cam_offset := Vector2.ZERO
# Kamera: 2.0 atrofida uzoqroq ko'rinish — dunyo ko'proq ko'rinadi.
var zoom := 1.09
const ZOOM_MIN := 0.55
const ZOOM_MAX := 4.5

var hovered_cell := Vector2i(0, 0)
var is_panning := false
var pan_last := Vector2.ZERO
var press_start := Vector2.ZERO
var did_drag := false

var player: Node2D = null

# =========================================================================
#  LAN CO-OP (2 kishilik) — ENet
# =========================================================================
const NET_PORT := 24565
var net_active := false
var net_is_host := false
var net_peers := {}              # peer_id -> {pos, flip, anim, frame}
var net_status := ""
var _net_send_t := 0.0
const NET_SEND_RATE := 0.05
var follow_player := true
var last_player_safe_pos := Vector2.ZERO

# Personaj daraxt bilan proporsional ko'rinsin.
const PLAYER_DRAW_SCALE := 0.09

# ---- SAKRASH (SPACE) ----
var jump_z := 0.0          # personaj yer ustidan balandligi
var jump_vel := 0.0        # sakrash tezligi
const JUMP_POWER := 90.0   # sakrash kuchi
const GRAVITY := 260.0     # tortishish

# ---- HAYVONLAR (spawn tizimi) ----
# Hayvon sahnalari (o'z fayl nomlaringga moslab o'zgartir)
const STAG_SCENE := "res://stag.tscn"
const BOAR_SCENE := "res://boar.tscn"
const SLIME_SCENE := "res://slime.tscn"
const FROG_SCENE := "res://frog.tscn"
var _animal_scenes := []
var animals := []                  # hozir dunyoda yurgan hayvonlar
var _anim_white_cache := {}        # hayvon kadrlarining oq versiyasi (hover kontur)
const MAX_ANIMALS := 2             # bir vaqtda nechta hayvon bo'lsin (juda kam)
const SPAWN_MIN_DIST := 280.0      # personajdan shu masofadan uzoqda paydo bo'ladi
const SPAWN_MAX_DIST := 500.0
const SPAWN_APART := 180.0         # hayvonlar bir-biridan shu masofada tarqoq chiqadi
const DESPAWN_DIST := 650.0        # bundan uzoqlashsa yo'qoladi
var _spawn_timer := 0.0
const SPAWN_INTERVAL := 6.0        # har necha soniyada tekshiradi (sekin)

# ---- HUD (jon, quvvat, hotbar) ----
var hud: CanvasLayer = null
var hud_node = null
const MAX_HEALTH := 10
var health := 10
var _hurt_cooldown := 0.0          # jon olgandan keyin qisqa himoya (invuln)
const MAX_STAMINA := 100.0
var stamina := 100.0
var selected_slot := 0            # 0..7 — tanlangan hotbar katagi
const HOTBAR_SLOTS := 8

# ---- OVOZLAR ----
const SFX_DIR := "res://assets/sounds/"
var _sfx := {}                 # nom -> AudioStream
var _sfx_players := []         # bir vaqtda bir nechta ovoz chalinishi uchun
const SFX_CHANNELS := 8
var _sfx_next := 0
var ambient_player: AudioStreamPlayer = null
var rain_player: AudioStreamPlayer = null

# ---- IKONKALAR ----
const ICON_DIR := "res://assets/icons/"
const UI_DIR := "res://assets/ui/"
var _icons := {}          # nom -> Texture2D
var _ui_box := {}         # nom -> Texture2D (slot ramkalari)

# ---- ASBOBLAR ----
# Har asbob: qaysi ishga yaraydi, zarar kuchi, qo'shimcha resurs
var TOOLS := {
	"Bolta":    {"good_for": "tree", "damage": 2, "bonus": 0},
	"Kirka":    {"good_for": "rock", "damage": 2, "bonus": 0},
	"Qilich":   {"good_for": "none", "damage": 1, "bonus": 0},
	"Belkurak": {"good_for": "none", "damage": 1, "bonus": 0},
}

# ---- INVENTAR ----
const INV_COLS := 8
const INV_ROWS := 4
const INV_SIZE := 32            # jami kataklar (8x4)
# Har katak: null yoki {"name": String, "icon": String, "count": int}
var inv := []
var inv_open := false           # inventar oynasi ochiqmi
var inv_hover := -1             # sichqoncha qaysi katak ustida

# ---- SUDRAB KO'CHIRISH (drag & drop) ----
# Inventar ochiq bo'lganda narsani ushlab, boshqa katakka (yoki hotbarga) olib qo'yish
var drag_item = null            # ushlangan narsa
var drag_from := -1             # qayerdan olingan

# ---- CRAFT (yasash) ----
# Har retsept: nomi, ikonka, kerakli yog'och/tosh
# CRAFTINGTABLE — qurilmalar tayyorlanadigan asosiy stol.
# Asboblar ANVIL orqali tayyorlanadi.
var RECIPES := [
	{"name": "Anvil",        "icon": "anvil",        "wood": 8,  "stone": 12},
	{"name": "Furnace",      "icon": "furnace",      "wood": 4,  "stone": 10},
	{"name": "Ko'ra",        "icon": "kiln",         "wood": 3,  "stone": 14},
	{"name": "Windmill",     "icon": "windmill",     "wood": 12, "stone": 6},
	{"name": "MagicTable",   "icon": "magic_table",  "wood": 20, "stone": 10},
	{"name": "Sandiq",       "icon": "chest",        "wood": 15, "stone": 0},
]

var ANVIL_RECIPES := [
	{"name": "Bolta",        "icon": "axe",         "wood": 5, "stone": 3},
	{"name": "Kirka",        "icon": "pickaxe",     "wood": 5, "stone": 5},
	{"name": "Mash'al",      "icon": "torch",       "wood": 2, "stone": 1},
	{"name": "Qilich",       "icon": "sword",       "wood": 3, "stone": 8},
	{"name": "Belkurak",     "icon": "shovel",      "wood": 4, "stone": 4},
	{"name": "Kamon",        "icon": "bow",         "wood": 6, "stone": 2},
	{"name": "Qarmoq",       "icon": "fishing_rod", "wood": 5, "stone": 1},
]
# Yasalgan narsalar: nom -> soni
var crafted := {}
var craft_open := false        # oddiy craft oynasi ochiqmi
var craft_hover := -1          # sichqoncha qaysi retsept ustida
var info_open := false         # chapdagi INFO paneli ochiqmi
var info_close_rect := Rect2()  # HUD tomonidan yangilanadi (yopish tugmasi)
var info_item := ""            # INFO panelda ko'rsatilayotgan narsa nomi
# Narsa tavsiflari (INFO paneli). Kalit = ichki nom.
const ITEM_INFO := {
	"Anvil": "Temirchilik stoli. Asboblar va qurollar shu yerda yasaladi.",
	"Furnace": "Ma'danlarni eritish uchun pech.",
	"Ko'ra": "Gil va qumdan buyum pishiriladigan ko'ra.",
	"Windmill": "Shamol tegirmoni. Bug'doyni unga aylantiradi.",
	"MagicTable": "Sehrli stol. Noyob buyumlar shu yerda yaratiladi.",
	"Sandiq": "Narsalarni saqlash uchun ombor.",
	"Bolta": "Daraxt kesish uchun. Ikki barobar tez chopadi.",
	"Kirka": "Tosh sindirish va yerni haydash uchun.",
	"Belkurak": "Yerni qazib suv chiqarish uchun.",
	"Qilich": "Himoya va jang uchun qurol.",
	"Kamon": "Uzoqdan otish uchun qurol.",
	"Qarmoq": "Suvdan baliq tutish uchun.",
	"Mash'al": "Qorong'ida yo'lni yoritadi.",
	"To'siq": "Hududni o'rab olish uchun devor.",
	"Ko'prik": "Suv ustidan o'tish uchun. Ustidan yuriladi.",
	"Yo'lak": "Tosh yo'lak. Yer ustiga yotqiziladi.",
	"Organ": "Sehrli musiqa asbobi. Bezak uchun.",
	"Qozon": "Ovqat pishirish uchun katta qozon.",
	"Kristall ustun": "Sehrli ustun. Kechasi atrofni yoritadi.",
	"Urug'": "Haydalgan yerga ekiladi. Bug'doy o'sadi.",
	"Bug'doy": "Hosil. Undan un va non tayyorlanadi.",
	"Yog'och": "Daraxtdan olinadi. Deyarli hamma narsaga kerak.",
	"Tosh": "Toshdan olinadi. Qurilish uchun asosiy material.",
	"O't": "Oddiy o't. Hayvonlarga yem bo'ladi.",
}
var craft_selected := 0          # crafting panelda oq ramka bilan tanlangan qator

# ---- MAGIC TABLE ----
const MAGIC_TABLE_PATH := "res://assets/objects/magictable.png"
const MAGIC_TABLE_MAX_HEIGHT := 40.0
const MAGIC_TABLE_MAX_WIDTH := 36.0
const MAGIC_TABLE_REACH := 72.0
var magic_table_texture: Texture2D = null
var magic_table_white: Texture2D = null
var magic_tables := {}
var magic_open := false
var magic_selected := 0
var MAGIC_RECIPES := [
	# Foydali, o'yinga ta'sir qiladigan narsalar (keraksizlari olib tashlandi)
	{"name":"To'siq", "icon":"fence", "wood":4, "stone":0, "copper":0},
	{"name":"Ko'prik", "icon":"bridge", "wood":6, "stone":0, "copper":0},
	{"name":"Yo'lak", "icon":"path", "wood":0, "stone":3, "copper":0},
	{"name":"Tosh maydon", "icon":"plaza", "wood":0, "stone":6, "copper":0},
	{"name":"Yog'och ustun", "icon":"post", "wood":3, "stone":0, "copper":0},
	{"name":"Organ", "icon":"organ", "wood":8, "stone":4, "copper":0},
	{"name":"Qozon", "icon":"cauldron", "wood":3, "stone":6, "copper":0},
	{"name":"Kristall ustun", "icon":"beacon", "wood":2, "stone":4, "copper":3},
	{"name":"Sehrli kristall", "icon":"ruby", "wood":10, "stone":3, "copper":2},
	{"name":"Kristall blok", "icon":"sapphire", "wood":3, "stone":5, "copper":0},
]

# ---- KO'PRIK (BRIDGE — suv ustiga qo'yiladi, ustidan yuriladi) ----
const BRIDGE_PATH := "res://assets/objects/Bridge.png"
const BRIDGE_MAX_HEIGHT := 26.0
const BRIDGE_MAX_WIDTH := 34.0
var bridge_texture: Texture2D = null
var bridge_white: Texture2D = null
var bridges := {}

# ---- YO'LAK (PATH — yerga yassi qo'yiladi, faqat toshdan) ----
const PATH_TEX_PATH := "res://assets/objects/stonepath_tile.png"
var path_texture: Texture2D = null
var paths := {}

# ---- ORGAN (weaving.png — dekorativ bino) ----
# Rasm fayli assets/objects/weaving.png deb nomlangan (organ.png yo'q).
const ORGAN_PATH := "res://assets/objects/weaving.png"
const ORGAN_MAX_HEIGHT := 40.0
const ORGAN_MAX_WIDTH := 34.0
var organ_texture: Texture2D = null
var organ_white: Texture2D = null
var organs := {}

# ---- YOG'OCH USTUN (POST — woodfans.png, dekorativ, harakatni to'sadi) ----
const POST_PATH := "res://assets/objects/woodfans.png"
const POST_MAX_HEIGHT := 40.0
const POST_MAX_WIDTH := 26.0
var post_texture: Texture2D = null
var post_white: Texture2D = null
var posts := {}

# ---- KO'RA (KILN — furnace_new.png, ikkinchi turdagi o'choq) ----
const KILN_PATH := "res://assets/objects/furnace_new.png"
const KILN_MAX_HEIGHT := 38.0
const KILN_MAX_WIDTH := 30.0
const KILN_REACH := 58.0
var kiln_texture: Texture2D = null
var kiln_white: Texture2D = null
var kilns := {}

# ---- TOSH MAYDON (PLAZA — stonepath.png, yerga yassi yotadi) ----
const PLAZA_PATH := "res://assets/objects/stonepath.png"
var plaza_texture: Texture2D = null
var plazas := {}

# ---- KRISTALL USTUN (BEACON — boshda paydo bo'ladi, kechqurun nur sochadi) ----
# Blender'dan chiqqan kadrlar (assets/objects/piller/anim) tools/make_pillar_sheet.py
# bilan sprite-sheet'ga aylantirilgan: 8x4 = 32 kadr, har biri 74x116.
# Suzish (tepa blokning tepaga-pastga qalqishi) va kristall pulsi RASMNING
# O'ZIDA bor — shuning uchun bu yerda qo'lda bob qilinmaydi.
const BEACON_SHEET_PATH := "res://assets/objects/pillar_anim.png"
const BEACON_SHEET_WHITE_PATH := "res://assets/objects/pillar_anim_white.png"
const BEACON_GLOW_PATH := "res://assets/objects/pillar_glow.png"
# Zaxira: agar sheet topilmasa, eski bitta kadrli rasmga qaytamiz.
const BEACON_PATH := "res://assets/objects/pillar.png"
const BEACON_MAX_HEIGHT := 90.0
const BEACON_MAX_WIDTH := 50.0
# Rasmning tepa 65.8% = kristall + blok (SUZADI), pastki qismi = poydevor (QIMIRLAMAYDI)
# — faqat ZAXIRA rasm uchun ishlatiladi.
const BEACON_SPLIT_FRAC := 0.658
const BEACON_COLS := 8
const BEACON_ROWS := 4
const BEACON_FRAMES := 32
const BEACON_FPS := 8.0                 # 32 kadr / 8 = 4 sekundlik tsikl
# Kadr ichidagi tinch holatdagi kadr (suzish o'rtasida) — ikona/arvoh/soya uchun
const BEACON_STILL_FRAME := 0
# Yerdagi nur dog'i: markazi kadr pastidan yuqoriga (kadr balandligining ulushi)
const BEACON_GLOW_Y_FRAC := 0.1747
const BEACON_GLOW_WIDE := 4.2           # keng yumshoq sha'la (kadr eniga nisbatan)
const BEACON_GLOW_CORE := 1.9           # markazdagi yorqin yadro
var beacon_sheet: Texture2D = null       # animatsiya kadrlari (bitta tekstura)
var beacon_sheet_white: Texture2D = null # hover konturi uchun oq siluet
var beacon_frame := Vector2.ZERO         # bitta kadr o'lchami (74x116)
var beacon_glow_tex: Texture2D = null    # yerga tushadigan iliq nur
var beacon_texture: Texture2D = null     # BITTA kadr (ikona, arvoh, soya)
var beacon_white: Texture2D = null
var beacons := {}                        # Vector2i -> true (qo'yilgan ustunlar)
var _beacon_t := 0.0
var _glow_tex: Texture2D = null   # tungi nur uchun yumshoq radial gradient

# ---- QOZON (CAULDRON — dekorativ bino) ----
const CAULDRON_PATH := "res://assets/objects/cauldron.png"
const CAULDRON_MAX_HEIGHT := 30.0
const CAULDRON_MAX_WIDTH := 32.0
var cauldron_texture: Texture2D = null
var cauldron_white: Texture2D = null
var cauldrons := {}

# ---- TO'SIQ (FENCE — dekorativ + harakatni to'sadi) ----
# Rasmni shu joyga qo'y: res://assets/objects/fence.png
const FENCE_PATH := "res://assets/objects/fence.png"
const FENCE_MAX_HEIGHT := 36.0
const FENCE_MAX_WIDTH := 40.0
const FENCE_REACH := 58.0
var fence_texture: Texture2D = null
var fence_white: Texture2D = null
var fences := {}

# ---- WORKBENCH / YASASH STOLI ----
# Rasmni shu joyga qo'y: res://assets/objects/workbench.png
const WORKBENCH_PATH := "res://assets/objects/workbench.png"
const WORKBENCH_MAX_HEIGHT := 34.0
const WORKBENCH_MAX_WIDTH := 34.0   # blok eni 32 -> stol blokka mos tushadi
const WORKBENCH_REACH := 58.0

var workbench_texture: Texture2D = null
var workbench_white: Texture2D = null
var workbenches := {}
var workbench_open := false

# ---- ANVIL / TEMIRCHILIK STOLI ----
const ANVIL_PATH := "res://assets/objects/anvil.png"
const ANVIL_MAX_HEIGHT := 30.0
const ANVIL_MAX_WIDTH := 34.0
const ANVIL_REACH := 58.0
var anvil_texture: Texture2D = null
var anvil_white: Texture2D = null
var anvils := {}
var anvil_open := false
var anvil_selected := 0

# ---- SANDIQ (CHEST) ----
# Rasmni shu yerga qo'y: res://assets/objects/chest.png
const CHEST_PATH := "res://assets/objects/chest.png"
const CHEST_MAX_HEIGHT := 30.0
const CHEST_MAX_WIDTH := 32.0
const CHEST_REACH := 58.0
const CHEST_COLS := 8
const CHEST_ROWS := 3
const CHEST_SIZE := 24          # 8x3 = 24 katak

var chest_texture: Texture2D = null
var chest_white: Texture2D = null
var chests := {}                # Vector2i -> Array (24 ta katak)
var chest_open := false
var open_chest_cell := Vector2i(999999, 999999)

# ---- KILN (Ko'ra) — VAQT bilan pishiriladigan qurilma ----
var kiln_open := false
var kiln_selected := 0
var open_kiln_cell := Vector2i(999999, 999999)
var kiln_jobs := {}   # Vector2i -> {recipe, elapsed, duration, ready}
var kiln_collect_rect := Rect2()  # HUD tomonidan yangilanadi
const KILN_MAX_READY := 5      # bir vaqtda ko'pi bilan nechta tayyor tursin
var KILN_RECIPES := [
	{"name": "Shisha", "icon": "sapphire", "stone": 3, "wood": 0, "time": 5.0},
	{"name": "G'isht", "icon": "silver_ore", "stone": 5, "wood": 0, "time": 6.0},
	{"name": "Ko'mir", "icon": "log", "stone": 0, "wood": 4, "time": 4.0},
	{"name": "Oltin quyma", "icon": "gold_ore", "stone": 0, "wood": 0, "gold": 3, "time": 8.0},
]

# ---- FURNACE / WINDMILL ----
# Ular ham workbench kabi dunyoga qo'yiladigan obyektlar.
const FURNACE_PATH := "res://assets/objects/furnace.png"
const WINDMILL_PATH := "res://assets/objects/windmill.png"
const FURNACE_MAX_HEIGHT := 40.0
const FURNACE_MAX_WIDTH := 34.0
const WINDMILL_MAX_HEIGHT := 116.0
const WINDMILL_MAX_WIDTH := 92.0
const BUILDING_REACH := 58.0

var furnace_texture: Texture2D = null
var furnace_white: Texture2D = null
var windmill_texture: Texture2D = null
var windmill_white: Texture2D = null
var furnaces := {}
var windmills := {}

# Obyektlarning holati:
#   E = 90 gradus aylantirish
#   Q = CHAPGA / O'NGGA qaratish (oyna qilib almashtirish)
# Izometrik rasm uchun aylantirishdan ko'ra FLIP tabiiyroq ko'rinadi.
var building_rotations := {}
var building_flips := {}          # Vector2i -> bool (chapga qaraganmi)
var placement_rotation := 0.0
var placement_flip := false

# Furnace va Windmill START inventarda bo'lmaydi.
# Ular faqat CRAFTINGTABLE orqali yog'och/tosh sarflab olinadi.
const GIVE_STARTER_BUILDINGS := false

# ---- YOMG'IR ----
var raining := false
var rain_drops := []          # har tomchi: {pos, speed, len}
const RAIN_COUNT := 220       # bir vaqtda nechta tomchi
var weather_timer := 0.0
var next_weather_change := 45.0   # necha soniyadan keyin ob-havo o'zgaradi
var rain_fade := 0.0          # 0..1 — yomg'ir kuchi (silliq boshlanadi/tugaydi)

# ---- SOYA ----
# Soya quyosh holatiga qarab uzayadi/qisqaradi va tomonini o'zgartiradi.
# Ertalab -> chapga, tush -> qisqa, kech -> o'ngga, tunda -> yo'q.
const SHADOW_MAX_SHEAR := 1.25    # eng uzun soya (ertalab/kech)
const SHADOW_SQUASH := 0.22       # yerga yotish darajasi (yassilik)
const SHADOW_ALPHA := 0.30        # eng quyuq holati
# TEZLIK: soyalar juda qimmat (har biri alohida transform).
# false qilsang FPS sezilarli oshadi (Settings > Video dan ham boshqariladi).
# Soyalar yoniq/o'chiqligi Lang.shadows da (Settings > Video).

# ---- TUN / KUNDUZ ----
var canvas_mod: CanvasModulate = null
var time_of_day := 0.30            # 0..1 (0.25 = tong, 0.5 = tush, 0.75 = kech, 0 = tun)
const DAY_LENGTH := 600.0          # bir kun necha soniya (kattaroq = sekinroq)

var broken := {}
# ---- TEZLIK uchun KESH (noise juda qimmat — natijani saqlaymiz) ----
var _gt_cache := {}      # Vector2i -> ground turi
var _dt_cache := {}      # Vector2i -> decor turi
# ---- 3D YER BLOKLARI (Blenderda yasalgan, qalinlikka ega) ----
const BLOCK_DIR := "res://assets/blocks/"
const BLOCK_SCALE := 0.5         # bloklar oldindan kichraytirilgan (90px -> 32px tayl)
var block_tex := {}
# FALSE = tekis tayl rejimi (yer = tile_040, suv = tile_104) — toza, "yoriqsiz".
# Yangi suv/yer bloklaringiz Blender'da tayyor bo'lgach TRUE qilamiz.
var use_blocks := false
var _tile_cache := {}    # Vector2i -> Texture2D (yer tayli — tayyor tekstura)
var _cliff_cache := {}   # Vector2i -> int bitmask (0=yo'q, 1=SE, 2=SW, 3=ikkisi)
var dug_cells := {}      # Belkurak -> suv
var tilled_cells := {}   # Kirka -> haydalgan tuproq (tile_004)
# ---- EKIN (crops) ----
var crops := {}          # Vector2i -> {stage:int, grow:float}
const CROP_STAGES := 4   # 0=urug', 1-2=o'sish, 3=pishgan
const CROP_GROW_TIME := 14.0   # har bosqich necha soniya (yomg'irda 2x tez)

# ---- AVTOSAQLASH ----
const AUTOSAVE_EVERY := 45.0   # necha soniyada bir marta o'zi saqlanadi
var _autosave_t := 0.0

# ---- EKRAN OGOHLANTIRISHI (chap yuqori burchak) ----
var hint_text := ""
var hint_timer := 0.0
# ---- TOAST (yig'ish bildirishnomalari, o'ng chetda pastdan-yuqoriga) ----
var toasts := []   # [{name, icon, count, timer}], yangisi 0-indeksda
const TOAST_LIFE := 2.2

# ---- TUTORIAL (o'rgatuvchi kartalar — chap yuqori burchak) ----
const TUTORIAL_SAVE := "user://aethera_tutorial.done"
var tutorial_active := true
var tutorial_index := 0
var tutorial_btn_rect := Rect2()
var tutorial_card_rect := Rect2()
# Har karta O'Z PAYTIDA chiqadi (hammasi birdaniga emas). "trigger" = shart:
#   start=darhol, moved=yurgach, near_tree=daraxt yaqinida, wood=yog'och yig'gach,
#   opened_inv=inventar ochgach, crafted=biror narsa yasagach, time=vaqt o'tgach
# Matnlar lang.gd da (3 tilda) — bu yerda faqat KALIT saqlanadi.
var tutorials := [
	{"key": "tut.move", "trigger": "start"},
	{"key": "tut.click", "trigger": "moved"},
	{"key": "tut.chop", "trigger": "near_tree"},
	{"key": "tut.inv", "trigger": "wood"},
	{"key": "tut.build", "trigger": "opened_inv"},
	{"key": "tut.dev", "trigger": "crafted"},
	{"key": "tut.zoom", "trigger": "time"},
]
var _tut_spawn_pos := Vector2.ZERO
var _tut_moved := false
var _tut_opened_inv := false
var _tut_time := 0.0

# ---- SETTINGS (sozlamalar menyusi — ESC bilan) ----
# Panelning O'ZI settings_panel.gd da (bosh menyu bilan bir xil dizayn).
# Qiymatlar Lang (autoload) da saqlanadi — menyuda o'zgartirsang o'yinda ham
# o'zgargan bo'ladi va user://aethera_settings.cfg ga yozib qo'yiladi.
var settings_open := false
var settings_panel: SettingsPanel = null
var join_ip := "127.0.0.1"        # ulanish uchun IP (LAN sahifasida yoziladi)
var typing_ip := false            # IP yozish rejimi
var chop_target = null
var chop_kind := ""
# Bitta klik daraxt/toshni tanlaydi va o'yinchi avtomatik ravishda
# asbob bilan kerakli marta urib, obyektni sindirguncha davom etadi.
var pending_chop_hits := 0
var chop_in_progress := false
var _last_path_target := Vector2i(999999, 999999)
var _chop_stuck := 0.0   # necha soniya to'xtab qoldi (yetib bo'lmadi tekshiruvi)
const CHOP_HIT_DELAY := 0.18

# Daraxt/tosh sog'ligi (nechта urish qolgani). Kalit: Vector2i, qiymat: int
var decor_hp := {}
const TREE_MAX_HP := 3
const ROCK_MAX_HP := 4
const STUMP_MAX_HP := 2    # kunda tez chopiladi
const GRASS_MAX_HP := 1    # O'T — bitta urishda kesiladi
# rock_01.png 562x444 bo'lgani uchun uni o'yin ichida kichraytiramiz.
# 28 px balandlik ISO tile (32x16) bilan mosroq ko'rinadi.
const ROCK_MAX_HEIGHT := 28.0

# Silkinish effekti: qaysi katak, qancha vaqt silkinadi
var shake_cell = null
var shake_timer := 0.0

# ---- URISH EFFEKTLARI ----
# Har urishda obyekt bir lahza OQARIB yonadi.
var flash_cell = null
var flash_timer := 0.0
const FLASH_TIME := 0.13

# Har urishda obyektdan mayda bo'laklar sakrab chiqadi.
# Har bo'lak: {pos, vel, z, zvel, life, size, color}
var hit_chips := []

# Obyekt orqasiga o'tilganda shaffoflik darajasi
const BEHIND_ALPHA := 0.40


# =========================================================================
#  RPC — o'yinchi holati va dunyo o'zgarishlari
# =========================================================================

# Har o'yinchi o'z holatini boshqalarga yuboradi
@rpc("any_peer", "unreliable")
func net_player_state(pos: Vector2, flip: bool, anim: String, frame: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		return
	net_peers[id] = {"pos": pos, "flip": flip, "anim": anim, "frame": frame}


# Daraxt/tosh sindi
@rpc("any_peer", "call_local", "reliable")
func net_broken(cell: Vector2i) -> void:
	broken[cell] = true
	_dt_cache.erase(cell)
	decor_hp.erase(cell)
	queue_redraw()


# Qurilma qo'yildi / olindi
@rpc("any_peer", "call_local", "reliable")
func net_place(kind: String, cell: Vector2i, rot: float, flip: bool) -> void:
	match kind:
		"workbench": workbenches[cell] = true
		"furnace": furnaces[cell] = true
		"windmill": windmills[cell] = true
		"magic_table": magic_tables[cell] = true
		"anvil": anvils[cell] = true
		"chest": chests[cell] = _new_chest_storage()
		"fence": fences[cell] = true
		"bridge": bridges[cell] = true
		"path": paths[cell] = true
		"organ": organs[cell] = true
		"post": posts[cell] = true
		"kiln": kilns[cell] = true
		"plaza": plazas[cell] = true
		"beacon": beacons[cell] = true
		"cauldron": cauldrons[cell] = true
	building_rotations[cell] = rot
	building_flips[cell] = flip
	queue_redraw()


@rpc("any_peer", "call_local", "reliable")
func net_remove(cell: Vector2i) -> void:
	for dict in [workbenches, furnaces, windmills, magic_tables, anvils,
			chests, fences, bridges, paths, organs, beacons, cauldrons,
			posts, kilns, plazas]:
		dict.erase(cell)
	building_rotations.erase(cell)
	building_flips.erase(cell)
	queue_redraw()


# Yer o'zgarishi: qazish / haydash / ekin
@rpc("any_peer", "call_local", "reliable")
func net_ground(kind: String, cell: Vector2i) -> void:
	match kind:
		"dug":
			dug_cells[cell] = true
			tilled_cells.erase(cell)
		"tilled":
			tilled_cells[cell] = true
		"plant":
			crops[cell] = {"stage": 0, "grow": 0.0}
		"harvest":
			crops.erase(cell)
	for dc in [-2, -1, 0, 1, 2]:
		for dr in [-2, -1, 0, 1, 2]:
			var k := cell + Vector2i(dc, dr)
			_gt_cache.erase(k)
			_dt_cache.erase(k)
			_tile_cache.erase(k)
			_cliff_cache.erase(k)
			_elev_cache.erase(k)
	queue_redraw()


# Host yangi ulangan o'yinchiga BUTUN dunyo holatini yuboradi
func _net_send_world_to(id: int) -> void:
	var data := {
		"broken": broken.keys(),
		"dug": dug_cells.keys(),
		"tilled": tilled_cells.keys(),
		"crops": crops,
		"workbenches": workbenches.keys(),
		"furnaces": furnaces.keys(),
		"windmills": windmills.keys(),
		"magic_tables": magic_tables.keys(),
		"anvils": anvils.keys(),
		"chests": chests.keys(),
		"fences": fences.keys(),
		"bridges": bridges.keys(),
		"paths": paths.keys(),
		"organs": organs.keys(),
		"beacons": beacons.keys(),
		"cauldrons": cauldrons.keys(),
		"posts": posts.keys(),
		"kilns": kilns.keys(),
		"plazas": plazas.keys(),
		"rotations": building_rotations,
		"flips": building_flips,
		"time": time_of_day,
	}
	net_world_sync.rpc_id(id, data)


@rpc("any_peer", "reliable")
func net_world_sync(data: Dictionary) -> void:
	for c in data.get("broken", []):
		broken[c] = true
	for c in data.get("dug", []):
		dug_cells[c] = true
	for c in data.get("tilled", []):
		tilled_cells[c] = true
	crops = data.get("crops", {}).duplicate(true)
	for c in data.get("workbenches", []):
		workbenches[c] = true
	for c in data.get("furnaces", []):
		furnaces[c] = true
	for c in data.get("windmills", []):
		windmills[c] = true
	for c in data.get("magic_tables", []):
		magic_tables[c] = true
	for c in data.get("anvils", []):
		anvils[c] = true
	for c in data.get("chests", []):
		chests[c] = _new_chest_storage()
	for c in data.get("fences", []):
		fences[c] = true
	for c in data.get("bridges", []):
		bridges[c] = true
	for c in data.get("paths", []):
		paths[c] = true
	for c in data.get("organs", []):
		organs[c] = true
	for c in data.get("beacons", []):
		beacons[c] = true
	for c in data.get("cauldrons", []):
		cauldrons[c] = true
	for c in data.get("posts", []):
		posts[c] = true
	for c in data.get("kilns", []):
		kilns[c] = true
	for c in data.get("plazas", []):
		plazas[c] = true
	building_rotations = data.get("rotations", {}).duplicate()
	building_flips = data.get("flips", {}).duplicate()
	time_of_day = float(data.get("time", time_of_day))
	_gt_cache.clear()
	_dt_cache.clear()
	_tile_cache.clear()
	_cliff_cache.clear()
	_elev_cache.clear()
	show_hint(Lang.t("hint.world_synced"), 2.5)
	queue_redraw()


# --- SERVER (host) ochish ---
func net_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(NET_PORT, 4)
	if err != OK:
		net_status = "Host xatosi: " + str(err)
		show_hint(net_status, 3.0)
		return
	multiplayer.multiplayer_peer = peer
	net_active = true
	net_is_host = true
	_net_connect_signals()
	net_status = "HOST — port " + str(NET_PORT)
	show_hint(Lang.t("hint.host_opened") + " " + str(NET_PORT), 4.0)
	queue_redraw()


# --- Do'st serveriga ulanish ---
func net_join(ip: String) -> void:
	var addr := ip.strip_edges()
	if addr == "":
		addr = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, NET_PORT)
	if err != OK:
		net_status = "Ulanish xatosi: " + str(err)
		show_hint(net_status, 3.0)
		return
	multiplayer.multiplayer_peer = peer
	net_active = true
	net_is_host = false
	_net_connect_signals()
	net_status = "Ulanmoqda: " + addr
	show_hint(net_status, 3.0)
	queue_redraw()


func net_disconnect() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	net_active = false
	net_is_host = false
	net_peers.clear()
	net_status = ""
	queue_redraw()


func _net_connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_ok):
		multiplayer.connected_to_server.connect(_on_connected_ok)
	if not multiplayer.connection_failed.is_connected(_on_connect_fail):
		multiplayer.connection_failed.connect(_on_connect_fail)
	if not multiplayer.server_disconnected.is_connected(_on_server_gone):
		multiplayer.server_disconnected.connect(_on_server_gone)


func _on_peer_connected(id: int) -> void:
	net_peers[id] = {"pos": Vector2.ZERO, "flip": false, "anim": "idle_Down", "frame": 0}
	show_hint(Lang.t("hint.player_joined") + " (" + str(id) + ")", 2.5)
	if net_is_host:
		_net_send_world_to(id)


func _on_peer_disconnected(id: int) -> void:
	net_peers.erase(id)
	show_hint(Lang.t("hint.player_left") + " (" + str(id) + ")", 2.5)


func _on_connected_ok() -> void:
	net_status = "Ulandi!"
	show_hint(net_status, 2.5)


func _on_connect_fail() -> void:
	show_hint(Lang.t("hint.connect_failed"), 3.0)
	net_disconnect()


func _on_server_gone() -> void:
	show_hint(Lang.t("hint.server_closed"), 3.0)
	net_disconnect()


func _ready() -> void:
	height_noise.seed = WORLD_SEED
	height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Pastroq frequency = KATTAROQ, kengroq suv havzalari (mayda ko'lmaklar emas).
	# 0.038 -> 0.018: ko'llar ancha kattaroq va uzluksiz bo'ladi (mayda ko'lmaklar emas).
	height_noise.frequency = 0.018
	height_noise.fractal_octaves = 3              # katta havza + tabiiy qirg'oq chiziq

	# ---- BIOM TIZIMI: HARORAT + NAMLIK (Minecraft uslubi) ----
	# Juda past frequency = JUDA KATTA, uzluksiz biomlar.
	# Bir biomdan boshqasiga yetish uchun uzoq yurish kerak bo'ladi.
	# 0.0016 -> 0.0011: biomlar yanada kengroq, qorli hudud uzoqda qoladi.
	biome_noise.seed = WORLD_SEED + 4242          # HARORAT
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome_noise.frequency = 0.0011
	biome_noise.fractal_octaves = 2               # silliq, mayda shovqinsiz

	humid_noise.seed = WORLD_SEED + 8888          # NAMLIK
	humid_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	humid_noise.frequency = 0.0015
	humid_noise.fractal_octaves = 2

	# ---- YER BALANDLIGI (terrasa darajalari) ----
	# Past frequency = kengroq, silliq balandlik zonalari (keskin sakramaydi).
	elev_noise.seed = WORLD_SEED + 555
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.frequency = 0.009
	elev_noise.fractal_octaves = 2

	decor_noise.seed = WORLD_SEED + 999
	decor_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	# Daraxtlarni mayda-mayda tasodifiy nuqtalar emas,
	# guruh-guruh o'rmon ko'rinishida chiqarishga yordam beradi.
	# Pastroq frequency = kattaroq, bir joyga yig'ilgan o'rmon zonalari.
	decor_noise.frequency = 0.07

	for d in TREE_DEFS:
		# Shaffof chetlarni kesamiz -> barcha daraxt bir xil o'lchovda bo'ladi
		var t = _load_cropped_texture(TREE_DIR + d[0] + ".png")
		if t != null:
			_tree_data.append({
				"name": d[0],
				"tex": t,
				"white": _make_white(t),
				"fw": t.get_width(),
				"fh": t.get_height(),
				"max_h": float(d[1]),
				"frames": 1
			})
		else:
			push_warning("Daraxt topilmadi: " + TREE_DIR + d[0] + ".png")

	# STUMP (kesilgan daraxt kundasi)
	grass_texture = _load_cropped_texture(GRASS_BLOCK_PATH)
	if grass_texture != null:
		grass_white = _make_white(grass_texture)
	else:
		push_warning("O't rasmi topilmadi: " + GRASS_BLOCK_PATH)
	var _gi = load(ASSET_DIR + "item_grass.png")
	if _gi != null:
		_icons["item_grass"] = _gi

	# Bug'doy o'sish bosqichlari
	# 3D yer bloklari (Blender)
	for bn in ["block_grass", "block_sand", "block_snow", "block_dirt", "block_water",
			"block_wheat_0", "block_wheat_1", "block_wheat_2", "block_wheat_3",
			"block_sand_tall", "block_snow_tall"]:
		var bt = load(BLOCK_DIR + bn + ".png")
		if bt != null:
			block_tex[bn] = bt
	if block_tex.is_empty():
		use_blocks = false
		push_warning("Yer bloklari topilmadi: " + BLOCK_DIR)

	wheat_textures.clear()
	for wi in range(4):
		var wt = _load_cropped_texture(WHEAT_DIR + "wheat_" + str(wi) + ".png")
		wheat_textures.append(wt)
		if wt == null:
			push_warning("Bug'doy rasmi topilmadi: wheat_" + str(wi) + ".png")
	var _wi = load(ASSET_DIR + "item_wheat.png")
	if _wi != null:
		_icons["item_wheat"] = _wi
	var _si = load(ASSET_DIR + "item_seed.png")
	if _si != null:
		_icons["item_seed"] = _si

	stump_texture = _load_cropped_texture(STUMP_PATH)
	if stump_texture != null:
		stump_white = _make_white(stump_texture)
	else:
		push_warning("Stump topilmadi: " + STUMP_PATH)

	if _tree_data.is_empty():
		push_error("Hech qanday daraxt yuklanmadi. assets/trees/ papkasini tekshiring.")

	# Drop itemlari — shaffof chet kesiladi.
	_wood_drop_texture = _load_cropped_texture(WOOD_DROP_PATH)
	_palm_drop_texture = _load_cropped_texture(PALM_DROP_PATH)
	_cactus_drop_texture = _load_cropped_texture(CACTUS_DROP_PATH)

	if _wood_drop_texture == null:
		push_warning("Yog'och item topilmadi: " + WOOD_DROP_PATH)
	if _palm_drop_texture == null:
		push_warning("Palma item topilmadi: " + PALM_DROP_PATH)
	if _cactus_drop_texture == null:
		push_warning("Kaktus item topilmadi: " + CACTUS_DROP_PATH)

	# Inventar/hotbar shu rasmlarni ikonka sifatida ishlatadi.
	if _wood_drop_texture != null:
		_icons["item_wood"] = _wood_drop_texture
	if _palm_drop_texture != null:
		_icons["item_palm"] = _palm_drop_texture
	if _cactus_drop_texture != null:
		_icons["item_cactus"] = _cactus_drop_texture

	for r in ROCK_DEFS:
		var rt = load(ROCK_DIR + r[0] + ".png") as Texture2D
		if rt != null:
			# rock_01 sprite-sheet emas, oddiy bitta PNG.
			# Shuning uchun uning haqiqiy o'lchamini avtomatik olamiz.
			_rock_data.append({
				"tex": rt,
				"white": _make_white(rt),
				"fw": rt.get_width(),
				"fh": rt.get_height()
			})
		else:
			push_warning("Tosh topilmadi: " + ROCK_DIR + r[0] + ".png")

	if has_node("Player"):
		player = get_node("Player")
		# Personajni "ko'rinmas" qilamiz — biz uni _draw ichida to'g'ri
		# chuqurlikda o'zimiz chizamiz (depth sorting uchun)
		player.visible = false

	# Hayvon sahnalarini yuklaymiz
	for path in [STAG_SCENE, BOAR_SCENE, SLIME_SCENE, FROG_SCENE]:
		var sc = load(path)
		if sc != null:
			_animal_scenes.append(sc)
	if _animal_scenes.is_empty():
		push_warning("Hayvon sahnalari topilmadi: " + STAG_SCENE + " / " + BOAR_SCENE)

	# Sahnada oldindan qo'yilgan hayvonlarni ro'yxatga olamiz
	for child in get_children():
		if child is AnimatedSprite2D and child != player:
			animals.append(child)

	# Tun/kunduz uchun butun ekranni bo'yaydigan node
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)

	# Inventarni bo'sh kataklar bilan to'ldiramiz
	inv.resize(INV_SIZE)
	for i in range(INV_SIZE):
		inv[i] = null

	# STARTER: Yasash stoli — HOTBAR'da emas, inventarning 2-qatorida.
	# U CHEKSIZ: qo'yganda kamaymaydi.
	# O'yinchi uni inventardan (I) hotbarga SUDRAB olib chiqadi.
	inv[HOTBAR_SLOTS] = {
		"name": "Yasash stoli",
		"icon": "workbench",
		"count": 1,
		"infinite": true,
	}
	# Boshlang'ich urug' (ekin ekish uchun)
	inv[HOTBAR_SLOTS + 1] = {"name": "Urug'", "icon": "item_seed", "count": 12}

	# Narsa ikonkalarini yuklaymiz.
	# YANGI itemlar (leather/mushroom/egg/cloth/thread/meat/jelly) — ikonka
	# fayli hali yo'q bo'lsa jimgina o'tkazib yuboriladi (null). assets/icons/
	# ichiga <nom>.png tashlaganingizda avtomatik ko'rinadi.
	for n in ["axe", "pickaxe", "sword", "torch", "shovel", "bow", "fishing_rod",
			"log", "silver_ore", "copper_ore", "gold_ore", "apple", "coin",
			"arrow", "bomb", "ruby", "emerald", "sapphire", "cactus",
			"workbench", "anvil", "furnace", "windmill",
			"leather", "mushroom", "egg", "cloth", "thread", "meat", "jelly"]:
		var ic = load(ICON_DIR + n + ".png")
		if ic != null:
			_icons[n] = ic

	workbench_texture = _load_cropped_texture(WORKBENCH_PATH) as Texture2D
	if workbench_texture != null:
		workbench_white = _make_white(workbench_texture)
	else:
		push_warning("Workbench rasmi topilmadi: " + WORKBENCH_PATH)

	anvil_texture = _load_cropped_texture(ANVIL_PATH) as Texture2D
	if anvil_texture != null:
		anvil_white = _make_white(anvil_texture)
	else:
		push_warning("Anvil rasmi topilmadi: " + ANVIL_PATH)

	furnace_texture = load(FURNACE_PATH) as Texture2D
	if furnace_texture != null:
		furnace_white = _make_white(furnace_texture)
	else:
		push_warning("Furnace rasmi topilmadi: " + FURNACE_PATH)

	windmill_texture = _load_cropped_texture(WINDMILL_PATH) as Texture2D
	if windmill_texture != null:
		windmill_white = _make_white(windmill_texture)
	else:
		push_warning("Windmill rasmi topilmadi: " + WINDMILL_PATH)

	chest_texture = _load_cropped_texture(CHEST_PATH) as Texture2D
	if chest_texture != null:
		chest_white = _make_white(chest_texture)
		_icons["chest"] = chest_texture
	else:
		push_warning("Sandiq rasmi topilmadi: " + CHEST_PATH)

	magic_table_texture = _load_cropped_texture(MAGIC_TABLE_PATH) as Texture2D
	if magic_table_texture != null:
		magic_table_white = _make_white(magic_table_texture)
		_icons["magic_table"] = magic_table_texture
	else:
		push_warning("MagicTable rasmi topilmadi: " + MAGIC_TABLE_PATH)

	cauldron_texture = _load_cropped_texture(CAULDRON_PATH) as Texture2D
	if cauldron_texture != null:
		cauldron_white = _make_white(cauldron_texture)
		_icons["cauldron"] = cauldron_texture
	else:
		push_warning("Qozon rasmi topilmadi: " + CAULDRON_PATH)

	fence_texture = _load_cropped_texture(FENCE_PATH) as Texture2D
	if fence_texture != null:
		fence_white = _make_white(fence_texture)
		_icons["fence"] = fence_texture
	else:
		push_warning("To'siq rasmi topilmadi: " + FENCE_PATH)

	bridge_texture = _load_cropped_texture(BRIDGE_PATH) as Texture2D
	if bridge_texture != null:
		bridge_white = _make_white(bridge_texture)
		_icons["bridge"] = bridge_texture
	else:
		push_warning("Ko'prik rasmi topilmadi: " + BRIDGE_PATH)

	path_texture = _load_cropped_texture(PATH_TEX_PATH) as Texture2D
	if path_texture != null:
		_icons["path"] = path_texture
	else:
		push_warning("Yo'lak rasmi topilmadi: " + PATH_TEX_PATH)

	organ_texture = _load_cropped_texture(ORGAN_PATH) as Texture2D
	if organ_texture != null:
		organ_white = _make_white(organ_texture)
		_icons["organ"] = organ_texture
	else:
		push_warning("Organ rasmi topilmadi: " + ORGAN_PATH)

	post_texture = _load_cropped_texture(POST_PATH) as Texture2D
	if post_texture != null:
		post_white = _make_white(post_texture)
		_icons["post"] = post_texture
	else:
		push_warning("Yog'och ustun rasmi topilmadi: " + POST_PATH)

	kiln_texture = _load_cropped_texture(KILN_PATH) as Texture2D
	if kiln_texture != null:
		kiln_white = _make_white(kiln_texture)
		_icons["kiln"] = kiln_texture
	else:
		push_warning("Ko'ra rasmi topilmadi: " + KILN_PATH)

	plaza_texture = _load_cropped_texture(PLAZA_PATH) as Texture2D
	if plaza_texture != null:
		_icons["plaza"] = plaza_texture
	else:
		push_warning("Tosh maydon rasmi topilmadi: " + PLAZA_PATH)

	_load_beacon_assets()

	# Tungi nur uchun yumshoq radial gradient (halqalarsiz, tabiiy halo)
	var _grad := Gradient.new()
	_grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_grad.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var _gt := GradientTexture2D.new()
	_gt.gradient = _grad
	_gt.fill = GradientTexture2D.FILL_RADIAL
	_gt.fill_from = Vector2(0.5, 0.5)
	_gt.fill_to = Vector2(1.0, 0.5)
	_gt.width = 256
	_gt.height = 256
	_glow_tex = _gt

	if GIVE_STARTER_BUILDINGS:
		add_item("Furnace", "furnace", 1)
		add_item("Windmill", "windmill", 1)

	# UI qutilari (slot ramkalari)
	for n in ["ui_grey_var_1", "ui_grey_var_3", "ui_white_var_2", "ui_tan_var_2"]:
		var b = load(UI_DIR + n + ".png")
		if b != null:
			_ui_box[n] = b

	# Ovozlarni yuklaymiz
	for n in ["chop_wood", "hit_stone", "tree_fall", "collect", "craft", "jump", "fail"]:
		var s = load(SFX_DIR + n + ".wav")
		if s != null:
			_sfx[n] = s
	# Bir nechta kanal — ovozlar bir-birini uzmasin
	for i in range(SFX_CHANNELS):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

	# QUSHLAR (ambient) — doim chalinadi
	ambient_player = _make_looping_player(["birds.ogg", "birds.mp3", "birds.wav"], -16.0)
	if ambient_player == null:
		push_warning("Qush ovozi topilmadi: " + SFX_DIR + "birds.(ogg/mp3/wav)")
	# YOMG'IR ovozi — doim chalinadi, lekin balandligi rain_fade ga qarab (_process da)
	rain_player = _make_looping_player(["rain.ogg", "rain.mp3", "rain.wav"], -60.0)
	if rain_player == null:
		push_warning("Yomg'ir ovozi topilmadi: " + SFX_DIR + "rain.(ogg/mp3/wav)")

	# HUD (ekran ustidagi panel) — kamera bilan harakatlanmaydi
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	hud_node = HudDraw.new()
	hud_node.world = self
	hud_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud_node)

	# Sozlamalar paneli (bosh menyu bilan bir xil)
	settings_panel = SettingsPanel.new()
	settings_panel.in_game = true
	apply_volumes()
	# Til almashsa HUD darhol yangilanadi
	Lang.language_changed.connect(_on_language_changed)

	# Kristall ustun (beacon) — o'yin boshida personaj oldida paydo bo'ladi
	if beacon_texture != null and player != null:
		beacons[local_to_grid(player.position) + Vector2i(2, 2)] = true
	if player != null:
		_tut_spawn_pos = player.position

	# Tutorial faqat BIRINCHI marta ko'rsatiladi (tugagach fayl saqlanadi).
	# Qayta ko'rmoqchi bo'lsang shu faylni o'chir: user://aethera_tutorial.done
	if FileAccess.file_exists(TUTORIAL_SAVE):
		tutorial_active = false

	cam_offset = get_viewport_rect().size / 2.0
	_apply_transform()

	# Bosh menyudan "CONTINUE" / "LOAD" bosilgan bo'lsa — saqlangan o'yinni tiklaymiz
	if Lang.load_on_start:
		Lang.load_on_start = false
		if load_game():
			show_hint(Lang.t("hint.loaded"), 2.0)

	# O'yin oynasi X bilan yopilsa ham saqlanadi
	get_tree().auto_accept_quit = false


func _on_language_changed() -> void:
	if hud_node != null:
		hud_node.queue_redraw()
	queue_redraw()


# Oyna yopilganda (X tugmasi / Alt+F4) — avtomatik saqlab chiqamiz
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


# =========================================================================
#  SAQLASH / YUKLASH  (user://aethera_save.json)
#
#  Dunyoning O'ZI WORLD_SEED dan hisoblanadi — shuning uchun faqat
#  O'YINCHI O'ZGARTIRGAN narsalar saqlanadi: sindirilgan daraxtlar,
#  qazilgan yer, ekinlar, qo'yilgan qurilmalar, sandiq ichidagilar,
#  inventar, jon, vaqt va personaj joyi.
#
#  Bosh menyudagi CONTINUE / LOAD shu faylni o'qiydi.
# =========================================================================

# Barcha qurilma lug'atlari: saqlash nomi -> lug'at (havola)
func _building_dicts() -> Dictionary:
	return {
		"workbench": workbenches,
		"furnace": furnaces,
		"kiln": kilns,
		"windmill": windmills,
		"magic_table": magic_tables,
		"anvil": anvils,
		"fence": fences,
		"bridge": bridges,
		"path": paths,
		"plaza": plazas,
		"organ": organs,
		"post": posts,
		"beacon": beacons,
		"cauldron": cauldrons,
	}


static func _ck(c: Vector2i) -> String:
	return str(c.x) + "," + str(c.y)


static func _kc(s: String) -> Vector2i:
	var parts := s.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _keys_to_list(d: Dictionary) -> Array:
	var out := []
	for k in d.keys():
		out.append(_ck(k))
	return out


const SAVE_VERSION := 1

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"time": time_of_day,
		"health": health,
		"stamina": stamina,
		"wood": wood_count,
		"stone": stone_count,
		"selected": selected_slot,
		"zoom": zoom,
		"player": [0.0, 0.0],
		"inv": [],
		"crafted": crafted.duplicate(),
		"broken": _keys_to_list(broken),
		"dug": _keys_to_list(dug_cells),
		"tilled": _keys_to_list(tilled_cells),
		"crops": {},
		"decor_hp": {},
		"buildings": {},
		"chests": {},
		"rot": {},
		"flip": {},
		"tutorial": {"active": tutorial_active, "index": tutorial_index},
	}

	if player != null:
		data["player"] = [player.position.x, player.position.y]

	for slot in inv:
		if slot == null:
			data["inv"].append(null)
		else:
			data["inv"].append({
				"name": str(slot.get("name", "")),
				"icon": str(slot.get("icon", "")),
				"count": int(slot.get("count", 0)),
				"infinite": bool(slot.get("infinite", false)),
			})

	for c in crops.keys():
		data["crops"][_ck(c)] = crops[c]
	for c in decor_hp.keys():
		data["decor_hp"][_ck(c)] = int(decor_hp[c])

	var bd := _building_dicts()
	for name in bd.keys():
		data["buildings"][name] = _keys_to_list(bd[name])

	# Sandiqlar — kataklari bilan
	for c in chests.keys():
		var arr := []
		for slot2 in chests[c]:
			if slot2 == null:
				arr.append(null)
			else:
				arr.append({
					"name": str(slot2.get("name", "")),
					"icon": str(slot2.get("icon", "")),
					"count": int(slot2.get("count", 0)),
				})
		data["chests"][_ck(c)] = arr

	for c in building_rotations.keys():
		data["rot"][_ck(c)] = float(building_rotations[c])
	for c in building_flips.keys():
		data["flip"][_ck(c)] = bool(building_flips[c])

	var f := FileAccess.open(Lang.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Saqlab bo'lmadi: " + Lang.SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(Lang.SAVE_PATH):
		return false
	var f := FileAccess.open(Lang.SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Saqlangan fayl buzilgan: " + Lang.SAVE_PATH)
		return false
	var data: Dictionary = parsed

	# Versiya tekshiruvi — kelajakda format o'zgarsa, eski/yangi save'lar
	# jimgina buzilib ketmasin. Hozircha faqat ogohlantiramiz.
	var save_ver := int(data.get("version", 0))
	if save_ver > SAVE_VERSION:
		push_warning("Save kelajakdagi versiyadan (v%d), o'yin v%d — ba'zi ma'lumot o'qilmasligi mumkin." % [save_ver, SAVE_VERSION])

	time_of_day = float(data.get("time", time_of_day))
	# Chegaralab o'qiymiz: buzuq yoki qo'lda o'zgartirilgan save o'yinni buzmasin
	health = clampi(int(data.get("health", health)), 0, MAX_HEALTH)
	stamina = clampf(float(data.get("stamina", stamina)), 0.0, MAX_STAMINA)
	wood_count = max(0, int(data.get("wood", 0)))
	stone_count = max(0, int(data.get("stone", 0)))
	selected_slot = clampi(int(data.get("selected", 0)), 0, HOTBAR_SLOTS - 1)
	zoom = clampf(float(data.get("zoom", zoom)), ZOOM_MIN, ZOOM_MAX)

	# --- Inventar ---
	var inv_list: Array = data.get("inv", [])
	for i in range(inv.size()):
		if i < inv_list.size() and typeof(inv_list[i]) == TYPE_DICTIONARY:
			var s: Dictionary = inv_list[i]
			var slot := {
				"name": str(s.get("name", "")),
				"icon": str(s.get("icon", "")),
				"count": int(s.get("count", 0)),
			}
			if bool(s.get("infinite", false)):
				slot["infinite"] = true
			inv[i] = slot
		else:
			inv[i] = null

	crafted = data.get("crafted", {}).duplicate()

	# --- Yer o'zgarishlari ---
	broken.clear()
	for k in data.get("broken", []):
		broken[_kc(str(k))] = true
	dug_cells.clear()
	for k in data.get("dug", []):
		dug_cells[_kc(str(k))] = true
	tilled_cells.clear()
	for k in data.get("tilled", []):
		tilled_cells[_kc(str(k))] = true

	crops.clear()
	var cr: Dictionary = data.get("crops", {})
	for k in cr.keys():
		var cv = cr[k]
		if typeof(cv) == TYPE_DICTIONARY:
			crops[_kc(str(k))] = {
				"stage": int(cv.get("stage", 0)),
				"grow": float(cv.get("grow", 0.0)),
			}

	decor_hp.clear()
	var dh: Dictionary = data.get("decor_hp", {})
	for k in dh.keys():
		decor_hp[_kc(str(k))] = int(dh[k])

	# --- Qurilmalar ---
	var bd := _building_dicts()
	var saved: Dictionary = data.get("buildings", {})
	for name in bd.keys():
		(bd[name] as Dictionary).clear()
		for k in saved.get(name, []):
			bd[name][_kc(str(k))] = true

	# --- Sandiqlar ---
	chests.clear()
	var ch: Dictionary = data.get("chests", {})
	for k in ch.keys():
		var store := _new_chest_storage()
		var arr = ch[k]
		if typeof(arr) == TYPE_ARRAY:
			for i in range(mini(store.size(), arr.size())):
				if typeof(arr[i]) == TYPE_DICTIONARY:
					store[i] = {
						"name": str(arr[i].get("name", "")),
						"icon": str(arr[i].get("icon", "")),
						"count": int(arr[i].get("count", 0)),
					}
		chests[_kc(str(k))] = store

	building_rotations.clear()
	var rt: Dictionary = data.get("rot", {})
	for k in rt.keys():
		building_rotations[_kc(str(k))] = float(rt[k])
	building_flips.clear()
	var fl: Dictionary = data.get("flip", {})
	for k in fl.keys():
		building_flips[_kc(str(k))] = bool(fl[k])

	# --- Tutorial ---
	var tut: Dictionary = data.get("tutorial", {})
	tutorial_active = bool(tut.get("active", false))
	tutorial_index = int(tut.get("index", 0))

	# --- Personaj ---
	var pp: Array = data.get("player", [])
	if player != null and pp.size() == 2:
		player.position = Vector2(float(pp[0]), float(pp[1]))

	# Keshlarni tozalaymiz — yer qaytadan hisoblanadi
	_gt_cache.clear()
	_dt_cache.clear()
	_tile_cache.clear()
	_cliff_cache.clear()
	_elev_cache.clear()
	_apply_transform()
	queue_redraw()
	if hud_node != null:
		hud_node.queue_redraw()
	return true


# Settings > Sound slayderlarini jonli qo'llaydi (ambient / weather).
# World SFX va Master play_sfx va AudioServer ichida hisoblanadi.
func apply_volumes() -> void:
	if ambient_player != null:
		ambient_player.volume_db = -16.0 + linear_to_db(maxf(0.0001, Lang.vol_ambient))
	if rain_player != null:
		rain_player.volume_db = lerpf(-60.0, -9.0, clampf(rain_fade, 0.0, 1.0)) 			+ linear_to_db(maxf(0.0001, Lang.vol_weather))


# Berilgan nomlardan (ogg/mp3/wav) birinchi mavjudini loop qilib chaladi.
func _make_looping_player(names: Array, db: float) -> AudioStreamPlayer:
	for nm in names:
		var path: String = SFX_DIR + str(nm)
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif "loop" in stream:
			stream.loop = true
		var pl := AudioStreamPlayer.new()
		pl.stream = stream
		pl.volume_db = db
		add_child(pl)
		pl.play()
		return pl
	return null


func _apply_transform() -> void:
	position = cam_offset
	scale = Vector2(zoom, zoom)
	queue_redraw()


# PNG atrofidagi ortiqcha shaffof bo'sh joyni kesib tashlaydi.
# Bu itemlar kichik va aniq ko'rinishi uchun kerak.
func _load_cropped_texture(path: String) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	var bbox := img.get_used_rect()
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return null
	var cropped := img.get_region(bbox)
	cropped.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(cropped)


# Rasmning OQ SILUET nusxasini yasaydi (kontur uchun).
# Modulate bilan oq bo'lmaydi (u ko'paytiradi), shuning uchun
# har bir shaffof bo'lmagan pikselni oq qilib yangi rasm yasaymiz.
func _make_white(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, c.a))
	return ImageTexture.create_from_image(img)


# ---- KRISTALL USTUN: animatsiya kadrlarini yuklash ----
# Sheet bo'lsa — jonli (suzadigan + pulsli) ustun.
# Sheet yo'q bo'lsa — eski bitta kadrli pillar.png (o'yin ishlashda davom etadi).
func _load_beacon_assets() -> void:
	beacon_glow_tex = load(BEACON_GLOW_PATH) as Texture2D

	beacon_sheet = load(BEACON_SHEET_PATH) as Texture2D
	if beacon_sheet != null:
		beacon_frame = Vector2(
			floorf(float(beacon_sheet.get_width()) / float(BEACON_COLS)),
			floorf(float(beacon_sheet.get_height()) / float(BEACON_ROWS)))
		beacon_sheet_white = load(BEACON_SHEET_WHITE_PATH) as Texture2D

		# Ikona / qo'yish arvohi / soya uchun BITTA kadrni ajratib olamiz.
		beacon_texture = _sheet_frame_texture(beacon_sheet, BEACON_STILL_FRAME)
		if beacon_sheet_white != null:
			beacon_white = _sheet_frame_texture(beacon_sheet_white, BEACON_STILL_FRAME)
		elif beacon_texture != null:
			beacon_white = _make_white(beacon_texture)

		if beacon_texture != null:
			_icons["beacon"] = beacon_texture
			return
		push_warning("Kristall ustun kadrini ajratib bo'lmadi: " + BEACON_SHEET_PATH)

	# --- ZAXIRA yo'l ---
	beacon_sheet = null
	beacon_sheet_white = null
	beacon_frame = Vector2.ZERO
	beacon_texture = _load_cropped_texture(BEACON_PATH) as Texture2D
	if beacon_texture != null:
		beacon_white = _make_white(beacon_texture)
		_icons["beacon"] = beacon_texture
	else:
		push_warning("Kristall ustun rasmi topilmadi: " + BEACON_PATH)


# Sprite-sheet'dan bitta kadrni alohida tekstura qilib qaytaradi.
func _sheet_frame_texture(sheet: Texture2D, index: int) -> Texture2D:
	if sheet == null or beacon_frame.x <= 0.0 or beacon_frame.y <= 0.0:
		return null
	var img := sheet.get_image()
	if img == null:
		return null
	var fw := int(beacon_frame.x)
	var fh := int(beacon_frame.y)
	var col := index % BEACON_COLS
	var row := (index / BEACON_COLS) % BEACON_ROWS
	var part := img.get_region(Rect2i(col * fw, row * fh, fw, fh))
	part.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(part)


# Vaqt bo'yicha joriy kadrning sheet ichidagi to'rtburchagi.
func _beacon_frame_region() -> Rect2:
	var idx := int(_beacon_t * BEACON_FPS) % BEACON_FRAMES
	var col := idx % BEACON_COLS
	var row := (idx / BEACON_COLS) % BEACON_ROWS
	return Rect2(float(col) * beacon_frame.x, float(row) * beacon_frame.y,
		beacon_frame.x, beacon_frame.y)


func _get_tex(tile_name: String) -> Texture2D:
	if not _tex_cache.has(tile_name):
		var path := ASSET_DIR + tile_name + ".png"
		var tex := load(path) as Texture2D

		# Agar texture topilmasa, o'yinni to'xtatib qo'ymaslik uchun
		# mavjud asosiy yer texture'siga o'tamiz.
		if tex == null:
			push_warning("Yer teksturasi topilmadi: " + path + " -> " + ASSET_DIR + LAND_TILE + ".png ishlatiladi")
			tex = load(ASSET_DIR + LAND_TILE + ".png") as Texture2D

		_tex_cache[tile_name] = tex

	return _tex_cache[tile_name]

func _stable_pick(list: Array, col: int, row: int, salt: int) -> String:
	var h = int(abs(hash(Vector3i(col, row, salt))))
	return list[h % list.size()]

func _stable_index(col: int, row: int, salt: int, size: int) -> int:
	var h = int(abs(hash(Vector3i(col, row, salt))))
	return h % size

# -------------------------------------------------------------------------
# BIOME BALANSI — SUV + QUM + YASHIL
#
# < WATER_LEVEL = WATER
# WATER_LEVEL..DIRT_LEVEL = DIRT
# >= DIRT_LEVEL = GRASS
#
# Suv juda ko'p chiqib ketmasligi uchun WATER_LEVEL pastroq qoldirilgan.
# -------------------------------------------------------------------------
# Suv qancha ko'p bo'lsin: kattaroq son = KO'PROQ suv
#   -0.52 (juda kam)  ...  -0.30 (juda ko'p)
const WATER_LEVEL := -0.42

# Cho'l qancha ko'p bo'lsin: KICHIKROQ son = KO'PROQ cho'l
#   0.28 (kam)  ...  0.05 (juda ko'p)
const SAND_LEVEL := 0.18   # (eski — endi ishlatilmaydi)
# Qor biomi: biome shu qiymatdan KICHIK bo'lsa qor (cho'lning teskarisi)
const SNOW_LEVEL := -0.28  # (eski — endi ishlatilmaydi)
# ---- HARORAT chegaralari (biome_noise) ----
const T_SNOW := -0.34      # bundan sovuq -> QOR
const T_TUNDRA := -0.20    # sovuq -> TUNDRA (qor atrofi)
const T_HOT := 0.30        # bundan issiq -> CHO'L (namlik ham quruq bo'lsa)
const T_WARM := 0.14       # iliq -> SAVANNA / STEPPE (o'tish)
# ---- NAMLIK chegaralari (humid_noise) ----
const H_DRY := -0.06       # bundan quruq -> cho'l/yaylov tomon
# ---- YER BALANDLIGI (qoya cheti / bloklar) ----
const CLIFF_DEPTH := 28.0   # yer qalinligi (px) — suv chetida ko'rinadi

func _ground_type(col: int, row: int) -> String:
	var key := Vector2i(col, row)
	# Belkurak bilan qazilgan katak -> SUV
	if dug_cells.has(key):
		return "water"
	# KESH: noise juda qimmat, bir marta hisoblab saqlaymiz
	if _gt_cache.has(key):
		return _gt_cache[key]
	var res := "grass"
	var h := height_noise.get_noise_2d(col, row)
	if h < WATER_LEVEL:
		res = "water"
	else:
		# HARORAT (t) va NAMLIK (w) -> biom. Chegaralar orasida
		# tabiiy O'TISH biomlari bor: savanna, steppe, tundra.
		var t := biome_noise.get_noise_2d(col, row)
		var w := humid_noise.get_noise_2d(col, row)
		if t < T_SNOW:
			res = "snow"                     # qorli hudud (eng sovuq)
		elif t < T_TUNDRA:
			res = "tundra"                   # sovuq tundra (qor atrofi)
		elif t > T_HOT and w < H_DRY:
			res = "sand"                     # cho'l (issiq + quruq)
		elif t > T_HOT:
			res = "savanna"                  # issiq, lekin nam -> quruq yaylov
		elif t > T_WARM and w < H_DRY:
			res = "steppe"                   # toshli dasht (cho'lga o'tish)
		elif t > T_WARM:
			res = "savanna"                  # quruq yaylov
	if _gt_cache.size() > 60000:
		_gt_cache.clear()
	_gt_cache[key] = res
	return res


# Shu katakning BALANDLIK DARAJASI (0..ELEV_LEVELS).
# Suv doim 0 (dengiz sathi). Quruqlik noise bo'yicha ko'tariladi.
func _elevation(col: int, row: int) -> int:
	if not ELEVATION_ENABLED:
		return 0
	var key := Vector2i(col, row)
	if _elev_cache.has(key):
		return _elev_cache[key]
	var lvl := 0
	if _ground_type(col, row) != "water":
		var n := elev_noise.get_noise_2d(col, row)   # ~[-1, 1]
		# Ko'p yer past (0-1), balandliklar kamroq — tabiiy terrasa
		if n > 0.10:
			lvl = 1
		if n > 0.34:
			lvl = 2
		if n > 0.58:
			lvl = 3
	if _elev_cache.size() > 60000:
		_elev_cache.clear()
	_elev_cache[key] = lvl
	return lvl


# Shu katak DRAW paytida necha px yuqoriga ko'tariladi
func _lift_px(col: int, row: int) -> float:
	if not ELEVATION_ENABLED:
		return 0.0
	return float(_elevation(col, row)) * LEVEL_LIFT


# Old qo'shni darajasi. Suv bo'lsa -1 (dengizga tushadigan cliff uchun).
func _front_level(col: int, row: int) -> int:
	if _ground_type(col, row) == "water":
		return -1
	return _elevation(col, row)


# Shu suv katagi uchun to'g'ri chetli taylni tanlaydi
func _water_tile_for(col: int, row: int) -> String:
	var m := 0
	if _ground_type(col - 1, row) != "water":
		m |= WATER_NW
	if _ground_type(col, row - 1) != "water":
		m |= WATER_NE
	if _ground_type(col + 1, row) != "water":
		m |= WATER_SE
	if _ground_type(col, row + 1) != "water":
		m |= WATER_SW

	if WATER_TILES.has(m):
		return str(WATER_TILES[m])
	# Uch tomonli / qarama-qarshi juftlik -> to'rt tomonli tayl
	return WATER_FALLBACK


func _decor_type(col: int, row: int, ground: String) -> String:
	if ground == "water":
		return ""

	var d := decor_noise.get_noise_2d(col, row)
	var r := float(int(abs(hash(Vector2i(col, row)))) % 1000) / 1000.0

	if ground == "sand":
		# QUM BIOME: kaktus + toshlar (o'rtacha zichlik).
		if r < 0.075:
			return "cactus"
		elif r > 0.96:
			return "rock"
		return ""

	if ground == "snow":
		# QOR BIOME: siyrak qorli archalar + toshlar
		if d > 0.30 and r < 0.22:
			return "tree"
		elif r > 0.96:
			return "rock"
		return ""

	if ground == "tundra":
		# TUNDRA: juda siyrak o'simlik, ko'p tosh (sovuq, ochiq)
		if d > 0.45 and r < 0.09:
			return "tree"
		elif r > 0.95:
			return "rock"
		return ""

	if ground == "steppe":
		# TOSHLI DASHT: ko'p tosh, juda kam daraxt (cho'lga o'tish)
		if d > 0.50 and r < 0.06:
			return "tree"
		elif r > 0.92:
			return "rock"
		return ""

	if ground == "savanna":
		# QURUQ YAYLOV: siyrak daraxtlar, o't, o'rtacha tosh
		if d > 0.38 and r < 0.14:
			return "tree"
		elif d > 0.05 and r > 0.58 and r < 0.635:
			return "grasstuft"
		elif r > 0.96:
			return "rock"
		return ""

	if ground == "grass":
		# YASHIL BIOME: lush o'rmon KLASTERLARI + ochiq maydonlar (ISO-CORE kabi)
		if d > 0.42 and r < 0.48:
			return "tree"
		elif d > 0.22 and r < 0.16:
			return "tree"
		# O'T — siyrak va KLASTERLI (ISO-CORE kabi ~4%, hamma joyda emas)
		elif d > 0.10 and r > 0.63 and r < 0.685:
			return "grasstuft"
		# Kunda — o'rmon chetlarida
		elif d > 0.30 and r > 0.93 and r < 0.945:
			return "stump"
		# Tosh — siyrak (~3%)
		elif r > 0.97:
			return "rock"

	return ""

func _decor_at(col: int, row: int) -> String:
	var key := Vector2i(col, row)
	if broken.has(key):
		return ""
	# Qazilgan katak SUV bo'ldi -> ustidagi daraxt/tosh yo'qoladi
	if dug_cells.has(key):
		return ""
	if _dt_cache.has(key):
		return _dt_cache[key]
	var d := _decor_type(col, row, _ground_type(col, row))
	if _dt_cache.size() > 60000:
		_dt_cache.clear()
	_dt_cache[key] = d
	return d


func grid_to_local(col: int, row: int) -> Vector2:
	return Vector2((col - row) * (TILE_W / 2.0), (col + row) * (TILE_H / 2.0))

func local_to_grid(pos: Vector2) -> Vector2i:
	var c = (pos.x / (TILE_W / 2.0) + pos.y / (TILE_H / 2.0)) / 2.0
	var r = (pos.y / (TILE_H / 2.0) - pos.x / (TILE_W / 2.0)) / 2.0
	return Vector2i(int(floor(c)), int(floor(r)))


func _draw_ground(tile_name: String, col: int, row: int) -> void:
	var tex: Texture2D = _get_tex(tile_name)

	# Texture umuman topilmasa ham null.get_width() xatosi chiqmasin.
	if tex == null:
		return

	var center := grid_to_local(col, row)
	draw_texture(
		tex,
		center - Vector2(float(tex.get_width()) / 2.0, float(tex.get_height()) / 2.0)
	)

# Yer chetidagi qoya (qalinlik) — suvга tushadigan front yuzlar.
# TEZLIK: qoya chetini keshlangan bitmask bilan chizadi
# Suv chegarasi bitmask (keshlangan) — baland blok kerakmi?
func _cliff_mask(col: int, row: int) -> int:
	var key := Vector2i(col, row)
	if _cliff_cache.has(key):
		return _cliff_cache[key]
	var m := 0
	if _ground_type(col, row) != "water":
		if _ground_type(col + 1, row) == "water":
			m |= 1
		if _ground_type(col, row + 1) == "water":
			m |= 2
	if _cliff_cache.size() > 60000:
		_cliff_cache.clear()
	_cliff_cache[key] = m
	return m


# Yer BLOKINI chizadi (Blender render, qalinlikka ega)
# Blok rasmlarida pastki qism 63-qatorda tugaydi (tall = 83).
# Shuning uchun pastki uchni rasm balandligidan emas, SHU qiymatdan olamiz.
const BLOCK_BASE_Y := 63.0        # oddiy blok pastki uchi (rasm ichida, px)
const BLOCK_BASE_Y_TALL := 83.0   # baland blok pastki uchi

func _draw_block(tex: Texture2D, col: int, row: int, sink: float = 0.0,
		tall: bool = false) -> void:
	if tex == null:
		return
	var tw := float(tex.get_width()) * BLOCK_SCALE
	var th := float(tex.get_height()) * BLOCK_SCALE
	var base := (BLOCK_BASE_Y_TALL if tall else BLOCK_BASE_Y) * BLOCK_SCALE
	var c := grid_to_local(col, row)
	# Blokning pastki uchi katak markazidan TILE_H/2 pastda tursin
	var pos := Vector2(c.x - tw / 2.0, c.y + TILE_H / 2.0 - base + sink)
	draw_texture_rect(tex, Rect2(pos, Vector2(tw, th)), false)


# Yer turi -> blok nomi
func _block_name_for(gr: String, cell: Vector2i) -> String:
	if tilled_cells.has(cell):
		return "block_dirt"
	match gr:
		"sand":
			return "block_sand"
		"snow", "tundra":
			return "block_snow"
		_:
			return "block_grass"


func _draw_cliff_cached(col: int, row: int) -> void:
	var key := Vector2i(col, row)
	var m: int
	if _cliff_cache.has(key):
		m = _cliff_cache[key]
	else:
		m = 0
		if _ground_type(col, row) != "water":
			if _ground_type(col + 1, row) == "water":
				m |= 1
			if _ground_type(col, row + 1) == "water":
				m |= 2
		if _cliff_cache.size() > 60000:
			_cliff_cache.clear()
		_cliff_cache[key] = m
	if m == 0:
		return
	var c := grid_to_local(col, row)
	var b := c + Vector2(0.0, TILE_H / 2.0)
	var rr := c + Vector2(TILE_W / 2.0, 0.0)
	var ll := c + Vector2(-TILE_W / 2.0, 0.0)
	var down := Vector2(0.0, CLIFF_DEPTH)
	if (m & 1) != 0:
		draw_colored_polygon(PackedVector2Array([b, rr, rr + down, b + down]),
			Color(0.50, 0.37, 0.24))
	if (m & 2) != 0:
		draw_colored_polygon(PackedVector2Array([ll, b, b + down, ll + down]),
			Color(0.38, 0.28, 0.17))


func _draw_cliff(col: int, row: int) -> void:
	var se_water := _ground_type(col + 1, row) == "water"
	var sw_water := _ground_type(col, row + 1) == "water"
	if not se_water and not sw_water:
		return
	var c := grid_to_local(col, row)
	var b := c + Vector2(0.0, TILE_H / 2.0)          # pastki burchak
	var rr := c + Vector2(TILE_W / 2.0, 0.0)          # o'ng burchak
	var ll := c + Vector2(-TILE_W / 2.0, 0.0)         # chap burchak
	var down := Vector2(0.0, CLIFF_DEPTH)
	var line := Color(0.26, 0.18, 0.11, 0.55)
	if se_water:
		draw_colored_polygon(PackedVector2Array([b, rr, rr + down, b + down]),
			Color(0.50, 0.37, 0.24))
		for k in range(1, 3):
			var t := float(k) / 3.0
			draw_line(b + down * t, rr + down * t, line, 1.0)
	if sw_water:
		draw_colored_polygon(PackedVector2Array([ll, b, b + down, ll + down]),
			Color(0.38, 0.28, 0.17))
		for k in range(1, 3):
			var t := float(k) / 3.0
			draw_line(ll + down * t, b + down * t, line, 1.0)


func _draw_rock(col: int, row: int) -> void:
	if _rock_data.is_empty():
		return
	var ri = _stable_index(col, row, 11, _rock_data.size())
	var info = _rock_data[ri]
	var tex = info["tex"]
	var fw = float(info["fw"])
	var fh = float(info["fh"])
	var center = grid_to_local(col, row)
	center.y -= _lift_px(col, row)     # terrasa balandligi

	# rock_01.png juda katta (562x444).
	# Uni ISO tile bilan mos bo'lishi uchun avtomatik kichraytiramiz.
	var draw_scale := minf(1.0, ROCK_MAX_HEIGHT / fh)
	var dw: float = fw * draw_scale
	var dh: float = fh * draw_scale

	# Toshning pastki qismi katak markaziga yerga o'tirgandek tushadi.
	var pos: Vector2 = center - Vector2(dw / 2.0, dh - TILE_H / 2.0)

	# OQ KONTUR
	if hovered_cell == Vector2i(col, row) and info.has("white") and info["white"] != null:
		for off in OUTLINE_OFFSETS:
			draw_texture_rect(
				info["white"],
				Rect2(pos + off, Vector2(dw, dh)),
				false
			)

	# Personajni to'sib qolsa — shaffof
	var rrect := Rect2(pos, Vector2(dw, dh))
	var ra := _behind_alpha(Vector2i(col, row), rrect)

	# Toshning o'zi
	draw_texture_rect(tex, rrect, false, Color(1, 1, 1, ra))

	# URISH PAYTIDA OQARIB YONADI
	var rfl := _flash_amount(Vector2i(col, row))
	if rfl > 0.0 and info.has("white") and info["white"] != null:
		draw_texture_rect(info["white"], rrect, false,
			Color(1, 1, 1, rfl * 0.85 * ra))


# Obyekt personajni to'sib qolyaptimi?
# Agar HA -> obyekt shaffof chiziladi va personaj ko'rinib turadi.
func _behind_alpha(cell: Vector2i, rect: Rect2) -> float:
	var s := cell.x + cell.y
	# --- Personaj orqasida bo'lsa ---
	if player != null \
			and absf(rect.position.x - player.position.x) <= 60.0 \
			and absf(rect.position.y - player.position.y) <= 80.0:
		var pc := local_to_grid(player.position)
		if s > (pc.x + pc.y):
			var pbox := Rect2(player.position - Vector2(9.0, 30.0), Vector2(18.0, 32.0))
			if rect.intersects(pbox):
				return BEHIND_ALPHA
	# --- Hayvon orqasida bo'lsa (personaj kabi shaffof bo'ladi) ---
	for a in animals:
		if not is_instance_valid(a):
			continue
		if absf(rect.position.x - a.position.x) > 60.0 \
				or absf(rect.position.y - a.position.y) > 80.0:
			continue
		var ac := local_to_grid(a.position)
		if s > (ac.x + ac.y):
			var abox := Rect2(a.position - Vector2(10.0, 22.0), Vector2(20.0, 26.0))
			if rect.intersects(abox):
				return BEHIND_ALPHA
	return 1.0


# Urish paytida obyekt bir lahza oqarib yonadi
func _flash_amount(cell: Vector2i) -> float:
	if flash_cell == null or flash_cell != cell or flash_timer <= 0.0:
		return 0.0
	return clampf(flash_timer / FLASH_TIME, 0.0, 1.0)


# =========================================================================
#  "R" TUGMASI BELGISI — ishlatish mumkin bo'lgan obyekt tepasida
# =========================================================================

# Qaysi qurilma yaqin va ochilishi mumkin?
# Qaytaradi: [cell, balandlik] yoki [] (yo'q)
# R belgisi FAQAT sichqoncha qurilma ustida turganda chiqadi
# (va o'yinchi yetarlicha yaqin bo'lsa).
func _nearby_interactable() -> Array:
	if player == null:
		return []

	var cell := hovered_cell
	var h := 0.0
	var reach := 0.0

	if workbenches.has(cell):
		h = WORKBENCH_MAX_HEIGHT
		reach = WORKBENCH_REACH
	elif anvils.has(cell):
		h = ANVIL_MAX_HEIGHT
		reach = ANVIL_REACH
	elif magic_tables.has(cell):
		h = MAGIC_TABLE_MAX_HEIGHT
		reach = MAGIC_TABLE_REACH
	elif chests.has(cell):
		h = CHEST_MAX_HEIGHT
		reach = CHEST_REACH
	elif kilns.has(cell):
		h = KILN_MAX_HEIGHT
		reach = BUILDING_REACH
	else:
		return []

	# O'yinchi yaqinmi?
	var p := grid_to_local(cell.x, cell.y)
	if player.position.distance_to(p) > reach:
		return []

	return [cell, h]


# Klaviatura tugmasi belgisi (reference rasmdagi kabi):
# qora yumaloq kvadrat + oq ramka + harf + pastda kichik uchburchak.
func _draw_key_badge(center: Vector2, letter: String) -> void:
	var s := 13.0            # belgi o'lchami
	var half := s / 2.0
	var rect := Rect2(center - Vector2(half, half), Vector2(s, s))

	# Oq ramka (tashqi)
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color(1, 1, 1, 0.95)
	outer.set_corner_radius_all(4)
	draw_style_box(outer, rect.grow(1.6))

	# Qora ichki qism
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.09, 0.09, 0.11, 0.98)
	inner.set_corner_radius_all(3)
	draw_style_box(inner, rect)

	# Pastdagi kichik uchburchak (obyektga ko'rsatadi)
	var tip := center + Vector2(0.0, half + 1.6)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-3.2, 0.0),
		tip + Vector2(3.2, 0.0),
		tip + Vector2(0.0, 4.2),
	]), Color(1, 1, 1, 0.95))

	# Harf
	var font := ThemeDB.fallback_font
	var fs := 11
	var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw / 2.0, 4.0), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))


# =========================================================================
#  QO'YISH ARVOHI — sichqoncha turgan katakda shaffof ko'rinish
# =========================================================================

# Qo'lda turgan qurilmaning rasmi va o'lchami.
# Qaytaradi: [tex, max_h, max_w] yoki []
func _equipped_building_info() -> Array:
	match get_equipped():
		"Yasash stoli":
			return [workbench_texture, WORKBENCH_MAX_HEIGHT, WORKBENCH_MAX_WIDTH]
		"Anvil":
			return [anvil_texture, ANVIL_MAX_HEIGHT, ANVIL_MAX_WIDTH]
		"Furnace":
			return [furnace_texture, FURNACE_MAX_HEIGHT, FURNACE_MAX_WIDTH]
		"Windmill":
			return [windmill_texture, WINDMILL_MAX_HEIGHT, WINDMILL_MAX_WIDTH]
		"MagicTable":
			return [magic_table_texture, MAGIC_TABLE_MAX_HEIGHT, MAGIC_TABLE_MAX_WIDTH]
		"Sandiq":
			return [chest_texture, CHEST_MAX_HEIGHT, CHEST_MAX_WIDTH]
		"To'siq":
			return [fence_texture, FENCE_MAX_HEIGHT, FENCE_MAX_WIDTH]
		"Ko'prik":
			return [bridge_texture, BRIDGE_MAX_HEIGHT, BRIDGE_MAX_WIDTH]
		"Organ":
			return [organ_texture, ORGAN_MAX_HEIGHT, ORGAN_MAX_WIDTH]
		"Yo'lak":
			return [path_texture, TILE_H * 2.0, TILE_W]
		"Kristall ustun":
			return [beacon_texture, BEACON_MAX_HEIGHT, BEACON_MAX_WIDTH]
		"Qozon":
			return [cauldron_texture, CAULDRON_MAX_HEIGHT, CAULDRON_MAX_WIDTH]
		"Yog'och ustun":
			return [post_texture, POST_MAX_HEIGHT, POST_MAX_WIDTH]
		"Ko'ra":
			return [kiln_texture, KILN_MAX_HEIGHT, KILN_MAX_WIDTH]
		"Tosh maydon":
			return [plaza_texture, TILE_H * 2.0, TILE_W]
	return []


# Sichqoncha turgan katakda qurilmani SHAFFOF ko'rsatadi.
# Yashil = qo'ysa bo'ladi, qizil = bo'lmaydi.
# Q bosilganda shu yerda darhol chapga/o'ngga aylanadi.
func _draw_placement_ghost() -> void:
	var info := _equipped_building_info()
	if info.is_empty():
		return
	var tex: Texture2D = info[0]
	if tex == null:
		return

	var cell := hovered_cell
	var can := _placement_ok(get_equipped(), cell)

	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())
	if tex_w <= 0.0 or tex_h <= 0.0:
		return

	var max_h: float = info[1]
	var max_w: float = info[2]
	var s := minf(1.0, max_h / tex_h)
	if max_w > 0.0:
		s = minf(s, max_w / tex_w)
	var dw := tex_w * s
	var dh := tex_h * s

	var center := grid_to_local(cell.x, cell.y)
	var pivot := center + Vector2(0.0, TILE_H / 2.0)

	# Katak ostida yashil/qizil romb
	var col: Color = Color(0.45, 1.0, 0.45, 0.30) if can else Color(1.0, 0.35, 0.30, 0.30)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -TILE_H / 2.0),
		center + Vector2(TILE_W / 2.0, 0),
		center + Vector2(0, TILE_H / 2.0),
		center + Vector2(-TILE_W / 2.0, 0),
	]), col)

	# Qurilmaning shaffof ko'rinishi (Q bilan aylantirilgan holatda)
	var sc := Vector2(-1.0, 1.0) if placement_flip else Vector2.ONE
	var tint: Color = Color(1, 1, 1, 0.55) if can else Color(1.0, 0.45, 0.40, 0.55)
	draw_set_transform(pivot, placement_rotation, sc)
	draw_texture_rect(tex, Rect2(Vector2(-dw / 2.0, -dh), Vector2(dw, dh)), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Kesilgan daraxt kundasi. To'siq emas — ustidan yurish mumkin.
# O't (grass tuft) — bitta urishda kesiladi, ustidan yuriladi
func _draw_grasstuft(cell: Vector2i) -> void:
	if grass_texture == null:
		return
	var center := grid_to_local(cell.x, cell.y)
	center.y -= _lift_px(cell.x, cell.y)     # terrasa balandligi
	var tw := float(grass_texture.get_width())
	var th := float(grass_texture.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sc := minf(1.0, GRASS_MAX_HEIGHT / th)
	sc = minf(sc, TILE_W / tw)
	var dw := tw * sc
	var dh := th * sc
	var pos := center - Vector2(dw / 2.0, dh - TILE_H / 2.0)
	var rect := Rect2(pos, Vector2(dw, dh))
	if hovered_cell == cell and grass_white != null:
		for off in OUTLINE_OFFSETS:
			draw_texture_rect(grass_white, Rect2(pos + off, Vector2(dw, dh)), false)
	draw_texture_rect(grass_texture, rect, false)
	var fl := _flash_amount(cell)
	if fl > 0.0 and grass_white != null:
		draw_texture_rect(grass_white, rect, false, Color(1, 1, 1, fl * 0.85))


func _draw_stump(cell: Vector2i) -> void:
	if stump_texture == null:
		return
	var center := grid_to_local(cell.x, cell.y)
	center.y -= _lift_px(cell.x, cell.y)     # terrasa balandligi
	var tw := float(stump_texture.get_width())
	var th := float(stump_texture.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var s := minf(1.0, STUMP_MAX_HEIGHT / th)
	var dw := tw * s
	var dh := th * s
	var pos := center - Vector2(dw / 2.0, dh - TILE_H / 2.0)
	draw_texture_rect(stump_texture, Rect2(pos, Vector2(dw, dh)), false)


func _draw_workbench(cell: Vector2i) -> void:
	_draw_placeable_object(cell, workbench_texture, workbench_white,
		WORKBENCH_MAX_HEIGHT, building_rotations.get(cell, 0.0), WORKBENCH_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_anvil(cell: Vector2i) -> void:
	_draw_placeable_object(cell, anvil_texture, anvil_white,
		ANVIL_MAX_HEIGHT, building_rotations.get(cell, 0.0), ANVIL_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_furnace(cell: Vector2i) -> void:
	_draw_placeable_object(cell, furnace_texture, furnace_white,
		FURNACE_MAX_HEIGHT, building_rotations.get(cell, 0.0), FURNACE_MAX_WIDTH,
		building_flips.get(cell, false))


func _draw_windmill(cell: Vector2i) -> void:
	_draw_placeable_object(cell, windmill_texture, windmill_white,
		WINDMILL_MAX_HEIGHT, building_rotations.get(cell, 0.0), WINDMILL_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_chest(cell: Vector2i) -> void:
	_draw_placeable_object(cell, chest_texture, chest_white,
		CHEST_MAX_HEIGHT, building_rotations.get(cell, 0.0), CHEST_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_magic_table(cell: Vector2i) -> void:
	_draw_placeable_object(cell, magic_table_texture, magic_table_white,
		MAGIC_TABLE_MAX_HEIGHT, building_rotations.get(cell, 0.0), MAGIC_TABLE_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_fence(cell: Vector2i) -> void:
	_draw_placeable_object(cell, fence_texture, fence_white,
		FENCE_MAX_HEIGHT, building_rotations.get(cell, 0.0), FENCE_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_bridge(cell: Vector2i) -> void:
	_draw_placeable_object(cell, bridge_texture, bridge_white,
		BRIDGE_MAX_HEIGHT, building_rotations.get(cell, 0.0), BRIDGE_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_cauldron(cell: Vector2i) -> void:
	_draw_placeable_object(cell, cauldron_texture, cauldron_white,
		CAULDRON_MAX_HEIGHT, building_rotations.get(cell, 0.0), CAULDRON_MAX_WIDTH,
		building_flips.get(cell, false))

func _draw_organ(cell: Vector2i) -> void:
	_draw_placeable_object(cell, organ_texture, organ_white,
		ORGAN_MAX_HEIGHT, building_rotations.get(cell, 0.0), ORGAN_MAX_WIDTH,
		building_flips.get(cell, false))

# Yog'och ustun (woodfans.png)
func _draw_post(cell: Vector2i) -> void:
	_draw_placeable_object(cell, post_texture, post_white,
		POST_MAX_HEIGHT, building_rotations.get(cell, 0.0), POST_MAX_WIDTH,
		building_flips.get(cell, false))

# Ko'ra (furnace_new.png)
func _draw_kiln(cell: Vector2i) -> void:
	_draw_placeable_object(cell, kiln_texture, kiln_white,
		KILN_MAX_HEIGHT, building_rotations.get(cell, 0.0), KILN_MAX_WIDTH,
		building_flips.get(cell, false))

# Tosh maydon (stonepath.png) — yo'lak kabi yerga YASSI yotadi
func _draw_plaza(cell: Vector2i) -> void:
	if plaza_texture == null:
		return
	var center := grid_to_local(cell.x, cell.y)
	# Rasm bitta katakni to'liq qoplaydi (chetlari qo'shnisi bilan tutashadi)
	var dw := TILE_W * 1.14
	var dh := TILE_H * 1.14
	draw_texture_rect(plaza_texture,
		Rect2(center - Vector2(dw / 2.0, dh / 2.0), Vector2(dw, dh)), false)

# Yo'lak — yassi, yer ustiga chiziladi (bino emas, ustidan yuriladi)
# Haydalgan tuproqqa urug' ekadi
func _plant_seed(cell: Vector2i) -> void:
	if player == null:
		return
	if player.position.distance_to(grid_to_local(cell.x, cell.y)) > BUILDING_REACH:
		_last_path_target = Vector2i(999999, 999999)
		_walk_player_to_cell(cell, true)
		return
	if count_item("Urug'") <= 0:
		return
	consume_equipped(1)
	crops[cell] = {"stage": 0, "grow": 0.0}
	if net_active:
		net_ground.rpc("plant", cell)
	if player.has_method("face_point"):
		player.face_point(grid_to_local(cell.x, cell.y))
	if player.has_method("do_action"):
		player.do_action("dig")
	play_sfx("collect", -11.0, 0.15)
	queue_redraw()


# Pishgan ekinni yig'adi (bug'doy + urug' qaytaradi)
func _harvest_crop(cell: Vector2i) -> void:
	if player == null or not crops.has(cell):
		return
	if player.position.distance_to(grid_to_local(cell.x, cell.y)) > BUILDING_REACH:
		_last_path_target = Vector2i(999999, 999999)
		_walk_player_to_cell(cell, true)
		return
	var c: Dictionary = crops[cell]
	if int(c["stage"]) < CROP_STAGES - 1:
		show_hint(Lang.t("hint.not_ripe"))
		return
	crops.erase(cell)
	if net_active:
		net_ground.rpc("harvest", cell)
	var wheat_amt := randi_range(2, 3)
	var seed_amt := randi_range(1, 2)
	add_item("Bug'doy", "item_wheat", wheat_amt)
	add_item("Urug'", "item_seed", seed_amt)
	_toast("Bug'doy", "item_wheat", wheat_amt)
	_toast("Urug'", "item_seed", seed_amt)
	if player.has_method("face_point"):
		player.face_point(grid_to_local(cell.x, cell.y))
	play_sfx("collect", -6.0, 0.1)
	queue_redraw()


# Ekinni chizadi (bosqichga qarab o'sadi; pishganda oltin rang)
func _draw_crop(cell: Vector2i) -> void:
	if not crops.has(cell):
		return
	var c: Dictionary = crops[cell]
	var stage: int = clampi(int(c["stage"]), 0, CROP_STAGES - 1)
	var center := grid_to_local(cell.x, cell.y)
	# Sprite bor bo'lsa — o'shani chizamiz
	var tex: Texture2D = null
	if stage < wheat_textures.size():
		tex = wheat_textures[stage]
	if tex != null:
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		if tw > 0.0 and th > 0.0:
			var sc := minf(1.0, WHEAT_MAX_HEIGHT / th)
			sc = minf(sc, (TILE_W * 1.25) / tw)
			var dw := tw * sc
			var dh := th * sc
			draw_texture_rect(tex,
				Rect2(center - Vector2(dw / 2.0, dh - TILE_H / 2.0), Vector2(dw, dh)),
				false)
			return
	# Zaxira: sprite yo'q bo'lsa kod bilan chizamiz
	var h := 3.0 + float(stage) * 4.5
	var mature := stage >= CROP_STAGES - 1
	var stalk := Color(0.90, 0.75, 0.28) if mature else Color(0.40, 0.72, 0.32)
	for dx in [-5.0, 0.0, 5.0]:
		var base := center + Vector2(dx, 3.0)
		draw_line(base, base - Vector2(0.0, h), stalk, 2.0)
		if mature:
			draw_circle(base - Vector2(0.0, h), 2.6, Color(0.96, 0.82, 0.32))


func _draw_path(cell: Vector2i) -> void:
	if path_texture == null:
		return
	var center := grid_to_local(cell.x, cell.y)
	var tw := float(path_texture.get_width())
	var th := float(path_texture.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	# Bitta tosh plita — katakni TO'LIQ qoplaydi.
	# Biroz kattaroq (1.12x) qilamiz: qo'shni plitalar bilan tutashadi,
	# orasidan yashil yer ko'rinib qolmaydi.
	var dw := TILE_W * 1.12
	var dh := TILE_H * 1.12
	var pos := center - Vector2(dw / 2.0, dh / 2.0)
	draw_texture_rect(path_texture, Rect2(pos, Vector2(dw, dh)), false)

# Kristall ustun (beacon) — sekin tepaga-pastga suzadi.
# Sheet bo'lsa: suzish va kristall pulsi rasmning o'zida (Blender'da) tayyor,
# biz faqat kadrni almashtiramiz. Sheet yo'q bo'lsa — eski qo'lda bob usuli.
func _draw_beacon(cell: Vector2i) -> void:
	if beacon_sheet != null and beacon_frame.x > 0.0 and beacon_frame.y > 0.0:
		_draw_beacon_animated(cell)
		return
	_draw_beacon_static(cell)


func _draw_beacon_animated(cell: Vector2i) -> void:
	var center := grid_to_local(cell.x, cell.y)
	var fw := beacon_frame.x
	var fh := beacon_frame.y
	var sscale := minf(1.0, BEACON_MAX_HEIGHT / fh)
	if BEACON_MAX_WIDTH > 0.0:
		sscale = minf(sscale, BEACON_MAX_WIDTH / fw)
	var dw := fw * sscale
	var dh := fh * sscale
	# Poydevorning pastki uchi katak romb'ining pastki uchida turadi.
	var rect := Rect2(center.x - dw / 2.0, center.y + TILE_H / 2.0 - dh, dw, dh)
	var region := _beacon_frame_region()

	# Hover konturi — joriy kadrning oq siluetidan
	if hovered_cell == cell and beacon_sheet_white != null:
		for off in OUTLINE_OFFSETS:
			draw_texture_rect_region(beacon_sheet_white,
				Rect2(rect.position + off, rect.size), region)

	draw_texture_rect_region(beacon_sheet, rect, region)


func _draw_beacon_static(cell: Vector2i) -> void:
	if beacon_texture == null:
		return
	var center := grid_to_local(cell.x, cell.y)
	var tw := float(beacon_texture.get_width())
	var th := float(beacon_texture.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sscale := minf(1.0, BEACON_MAX_HEIGHT / th)
	if BEACON_MAX_WIDTH > 0.0:
		sscale = minf(sscale, BEACON_MAX_WIDTH / tw)
	var dw := tw * sscale
	# Rasmni ikkiga bo'lamiz (manba piksel bo'yicha):
	#   tepa = kristall + blok (suzadi),  past = poydevor (qimirlamaydi)
	var split := floorf(th * BEACON_SPLIT_FRAC)
	var float_src_h := split
	var base_src_h := th - split
	var float_dh := float_src_h * sscale
	var base_dh := base_src_h * sscale
	var left := center.x - dw / 2.0
	var base_bottom := center.y + TILE_H / 2.0
	var bob := sin(_beacon_t * 1.4) * 4.0            # sekin suzish

	# --- Poydevor (QIMIRLAMAYDI) ---
	var base_rect := Rect2(left, base_bottom - base_dh, dw, base_dh)
	# --- Kristall + blok (SUZADI) ---
	var float_bottom := base_bottom - base_dh - bob
	var float_rect := Rect2(left, float_bottom - float_dh, dw, float_dh)

	# Hover konturi (ikkala bo'lakka)
	if hovered_cell == cell and beacon_white != null:
		for off in OUTLINE_OFFSETS:
			draw_texture_rect_region(beacon_white,
				Rect2(base_rect.position + off, base_rect.size),
				Rect2(0.0, split, tw, base_src_h))
			draw_texture_rect_region(beacon_white,
				Rect2(float_rect.position + off, float_rect.size),
				Rect2(0.0, 0.0, tw, float_src_h))

	draw_texture_rect_region(beacon_texture, base_rect,
		Rect2(0.0, split, tw, base_src_h))
	draw_texture_rect_region(beacon_texture, float_rect,
		Rect2(0.0, 0.0, tw, float_src_h))

# Beacon tungi yorug'ligi (kechqurun sha'la vazifasi)
func _draw_beacon_glow() -> void:
	if beacon_texture == null or beacons.is_empty():
		return
	# Nur DOIM bor (kunduzi kuchsizroq, tunda kuchli) — ISO-CORE kabi
	var night := 1.0 - _daylight()
	var strength: float = 0.40 + 0.60 * night
	var pulse := 0.90 + 0.10 * sin(_beacon_t * 2.0)
	var warm := Color(1.0, 0.86, 0.52)

	# Ustun rasmining o'yindagi o'lchami — nur shunga qarab kattalashadi
	var fw: float = float(beacon_texture.get_width())
	var fh: float = float(beacon_texture.get_height())
	if beacon_sheet != null and beacon_frame.x > 0.0 and beacon_frame.y > 0.0:
		fw = beacon_frame.x
		fh = beacon_frame.y
	if fw <= 0.0 or fh <= 0.0:
		return
	var sscale := minf(1.0, BEACON_MAX_HEIGHT / fh)
	if BEACON_MAX_WIDTH > 0.0:
		sscale = minf(sscale, BEACON_MAX_WIDTH / fw)
	var dw := fw * sscale
	var dh := fh * sscale

	# Blender'da chizilgan iliq dog' bo'lsa — shuni ishlatamiz (yerga yotadi,
	# ustunning poydevori bilan aniq bir joyda turadi).
	if beacon_glow_tex != null:
		var gw0 := float(beacon_glow_tex.get_width())
		var gh0 := float(beacon_glow_tex.get_height())
		var aspect: float = (gh0 / gw0) if gw0 > 0.0 else 0.58
		for bcell in beacons.keys():
			var base := grid_to_local(bcell.x, bcell.y) + Vector2(0.0, TILE_H / 2.0)
			var c := Vector2(base.x, base.y - dh * BEACON_GLOW_Y_FRAC)
			# 1) keng yumshoq sha'la
			var gw: float = dw * BEACON_GLOW_WIDE * pulse
			var gh: float = gw * aspect
			draw_texture_rect(beacon_glow_tex,
				Rect2(c - Vector2(gw, gh) / 2.0, Vector2(gw, gh)),
				false, Color(warm.r, warm.g, warm.b, 0.40 * strength))
			# 2) markazdagi yorqin yadro
			var gw2: float = dw * BEACON_GLOW_CORE * pulse
			var gh2: float = gw2 * aspect
			draw_texture_rect(beacon_glow_tex,
				Rect2(c - Vector2(gw2, gh2) / 2.0, Vector2(gw2, gh2)),
				false, Color(1.0, 0.93, 0.70, 0.50 * strength))
		return

	# ZAXIRA: protsedural gradient (eski usul)
	if _glow_tex == null:
		return
	for bcell2 in beacons.keys():
		var center = grid_to_local(bcell2.x, bcell2.y) + Vector2(0.0, -6.0)
		var rx: float = 86.0 * pulse
		var ry: float = rx * 0.52
		draw_texture_rect(_glow_tex,
			Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)),
			false, Color(warm.r, warm.g, warm.b, 0.42 * strength))
		var rx2: float = 46.0 * pulse
		var ry2: float = rx2 * 0.52
		draw_texture_rect(_glow_tex,
			Rect2(center - Vector2(rx2, ry2), Vector2(rx2 * 2.0, ry2 * 2.0)),
			false, Color(1.0, 0.93, 0.70, 0.45 * strength))


func _draw_placeable_object(
	cell: Vector2i,
	tex: Texture2D,
	white: Texture2D,
	max_height: float,
	rotation: float = 0.0,
	max_width: float = 0.0,
	flip: bool = false
) -> void:

	if tex == null:
		return

	var center := grid_to_local(cell.x, cell.y)
	center.y -= _lift_px(cell.x, cell.y)     # terrasa balandligi
	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())

	if tex_w <= 0.0 or tex_h <= 0.0:
		return

	# Faqat balandlik bo'yicha kichraytirish yetarli emas edi:
	# keng rasm (masalan workbench 422x356) blokdan ikki barobar
	# kengroq chiqib ketardi. Endi ENI ham cheklanadi.
	var draw_scale := minf(1.0, max_height / tex_h)
	if max_width > 0.0:
		draw_scale = minf(draw_scale, max_width / tex_w)
	var dw := tex_w * draw_scale
	var dh := tex_h * draw_scale
	# Ob'ektning pastki qismi ISO 32x16 katakning tagiga mahkamlanadi.
	var pivot := center + Vector2(0.0, TILE_H / 2.0)
	var draw_pos := Vector2(-dw / 2.0, -dh)

	# Chapga qaratish — rasmni oyna qilamiz (yangi rasm kerak emas)
	var sc := Vector2(-1.0, 1.0) if flip else Vector2.ONE

	if hovered_cell == cell and white != null:
		for off in OUTLINE_OFFSETS:
			draw_set_transform(pivot + off, rotation, sc)
			draw_texture_rect(white, Rect2(draw_pos, Vector2(dw, dh)), false)

	draw_set_transform(pivot, rotation, sc)
	draw_texture_rect(tex, Rect2(draw_pos, Vector2(dw, dh)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_decor(tile_name: String, col: int, row: int) -> void:
	var tex = _get_tex(tile_name)
	var center = grid_to_local(col, row)
	draw_texture(tex, center - Vector2(tex.get_width() / 2.0, tex.get_height() - TILE_H / 2.0))

func _get_tree_info_at(col: int, row: int):
	if _tree_data.is_empty():
		return null

	var ground := _ground_type(col, row)

	# QUM BIOME: kaktus (tree_05) + palma (tree_09).
	# Palma kamroq uchraydi — cho'lda kaktus ko'proq bo'lsin.
	if ground == "sand":
		var cactus_info = null
		var palm_info = null
		for info in _tree_data:
			var nm := str(info.get("name", ""))
			if nm == "tree_05":
				cactus_info = info
			elif nm == "tree_09":
				palm_info = info

		# Suv yaqinida -> PALMA (oaziz effekti)
		var near_water := (_ground_type(col - 1, row) == "water" or _ground_type(col + 1, row) == "water" \
			or _ground_type(col, row - 1) == "water" or _ground_type(col, row + 1) == "water")
		if near_water and palm_info != null:
			return palm_info
		# 20% palma, 80% kaktus (barqaror tanlov)
		var palm_roll := float(int(abs(hash(Vector2i(col * 7717, row * 3391)))) % 1000) / 1000.0
		if palm_roll < 0.20 and palm_info != null:
			return palm_info
		if cactus_info != null:
			return cactus_info
		return palm_info

	# TUNDRA: qorli archa (qor biomiga o'tish)
	if ground == "tundra":
		var tun_list: Array = []
		for info in _tree_data:
			var tnm := str(info.get("name", ""))
			if tnm == "tree_snow1" or tnm == "tree_snow2" or tnm == "tree_08":
				tun_list.append(info)
		if tun_list.size() > 0:
			return tun_list[_stable_index(col, row, 23, tun_list.size())]

	# QOR BIOME: faqat qorli archalar
	if ground == "snow":
		var snow_list: Array = []
		for info in _tree_data:
			var snm := str(info.get("name", ""))
			if snm == "tree_snow1" or snm == "tree_snow2":
				snow_list.append(info)
		if snow_list.size() > 0:
			return snow_list[_stable_index(col, row, 21, snow_list.size())]
		# zaxira: oddiy archa
		for info in _tree_data:
			if str(info.get("name", "")) == "tree_08":
				return info

	# Yashil biome: faqat oddiy daraxtlar.
	# Kaktus (tree_05) va palma (tree_09) bu yerda hech qachon chiqmaydi.
	var candidates: Array = []
	for info in _tree_data:
		var n := str(info.get("name", ""))
		if n == "tree_03" or n == "tree_08" or n == "tree_rare":
			candidates.append(info)

	if candidates.is_empty():
		return _tree_data[0]

	var rare_roll := float(int(abs(hash(Vector2i(col * 9283, row * 6899)))) % 10000) / 10000.0
	if rare_roll < RARE_TREE_CHANCE:
		for info in candidates:
			if info.get("name", "") == "tree_rare":
				return info

	return candidates[_stable_index(col, row, 7, candidates.size())]


func _draw_tree(col: int, row: int) -> void:
	if _tree_data.is_empty():
		return

	# Daraxt turi har doim drop tizimi bilan bir xil aniqlanadi.
	var info = _get_tree_info_at(col, row)
	if info == null:
		return

	var tex = info["tex"]
	var fw: int = int(info["fw"])
	var fh: int = int(info["fh"])
	var fcount: int = int(info["frames"])

	var frame: int = tree_anim_frame % fcount
	var center: Vector2 = grid_to_local(col, row)
	center.y -= _lift_px(col, row)     # terrasa balandligi

	# Silkinish
	if shake_cell != null and shake_cell == Vector2i(col, row) and shake_timer > 0:
		center.x += sin(shake_timer * 40.0) * 2.0

	var src := Rect2(
		frame * fw,
		0,
		fw,
		fh
	)

	# Har daraxtning O'Z maksimal balandligi bor.
	# (Kaktus daraxtlardan pastroq -> 40, oddiy daraxt -> 76)
	var my_max_h: float = float(info.get("max_h", TREE_MAX_HEIGHT))
	var draw_scale: float = minf(
		1.0,
		my_max_h / float(fh)
	)

	var dw: float = float(fw) * draw_scale
	var dh: float = float(fh) * draw_scale

	var dst_pos: Vector2 = center - Vector2(
		dw / 2.0,
		dh - TILE_H / 2.0
	)

	# OQ KONTUR
	if hovered_cell == Vector2i(col, row):
		if info.has("white") and info["white"] != null:
			for off in OUTLINE_OFFSETS:
				draw_texture_rect_region(
					info["white"],
					Rect2(
						dst_pos + off,
						Vector2(dw, dh)
					),
					src
				)

	# Personajni to'sib qolsa — shaffof chizamiz
	var rect := Rect2(dst_pos, Vector2(dw, dh))
	var a := _behind_alpha(Vector2i(col, row), rect)

	# Daraxtning o'zi
	draw_texture_rect_region(tex, rect, src, Color(1, 1, 1, a))

	# URISH PAYTIDA OQARIB YONADI
	var fl := _flash_amount(Vector2i(col, row))
	if fl > 0.0 and info.has("white") and info["white"] != null:
		draw_texture_rect_region(info["white"], rect, src,
			Color(1, 1, 1, fl * 0.85 * a))
# Kichik O'TIN itemlari.
# Endi Woods.png sprite-sheet kerak emas — item.zip dagi tayyor log PNGlar ishlatiladi.
const WOOD_DROP_SIZE := Vector2(13.0, 11.0)
const STONE_DROP_SIZE := Vector2(13.0, 13.0)

# Sakrab chiqqan resurs itemining holatlari (state-machine).
# String literal o'rniga shu constlarni ishlatamiz: terish xatosi
# (masalan WOOD_FLu) endi runtime'da emas, parse vaqtida ushlanadi.
const WOOD_FLY := "fly"            # havoda uchib-tushmoqda
const WOOD_SETTLE := "settle"      # yerda yotibdi, personajni kutmoqda
const WOOD_TO_PLAYER := "to_player" # personajga uchib bormoqda

# Daraxt/tosh singanda resurs sakratib chiqaramiz
# kind: "wood" yoki "stone"
func _spawn_drop(cell: Vector2i, kind: String, bonus: int = 0) -> void:
	var center := grid_to_local(cell.x, cell.y)
	# Kunda atigi 1 ta yog'och beradi, qolganlari 2-3 ta
	var amount: int = 1 if (kind == "stump_wood" or kind == "grass") else randi_range(2, 3) + maxi(0, bonus)

	# Qaysi daraxt kesildi — o'sha turdagi item tushadi:
	#   tree_05 (kaktus) -> Kaktus       (tree_06 rasmi)
	#   tree_09 (palma)  -> Palma yog'ochi (tree_01 rasmi)
	#   qolgani          -> Yog'och      (tree_07 rasmi)
	var drop_kind := kind

	# DIQQAT: bu funksiya chaqiruvda kind = "wood" yoki "stone" bo'ladi
	# (chop kodi "tree" emas, "wood" yuboradi). Shuning uchun
	# "stone" dan boshqa hamma narsani daraxt deb tekshiramiz.
	# Avval `if kind == "tree"` edi -> hech qachon bajarilmasdi va
	# kaktusdan ham doim oddiy o'tin tushardi.
	if kind != "stone" and kind != "stump_wood" and kind != "grass":
		var tree_info = _get_tree_info_at(cell.x, cell.y)
		var tree_name := ""
		if tree_info != null:
			tree_name = str(tree_info.get("name", ""))
		match tree_name:
			"tree_05":
				drop_kind = "cactus"
			"tree_09":
				drop_kind = "palm"
			_:
				drop_kind = "wood"

	for i in range(amount):
		var angle := randf() * TAU
		var speed := randf_range(22.0, 46.0)

		# Toshdan ba'zan OLTIN yoki SAFIR chiqadi
		var this_kind := drop_kind
		if drop_kind == "stone":
			var roll := randf()
			if roll < GEM_CHANCE:
				this_kind = "gem"
			elif roll < GEM_CHANCE + GOLD_CHANCE:
				this_kind = "gold"

		wood_items.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"z": 0.0,
			"zvel": randf_range(30.0, 52.0),
			"variant": 0,
			"state": WOOD_FLY,
			"kind": this_kind,
			"born": Time.get_ticks_msec(),
		})

	var label := "resurs"
	if DROP_ITEMS.has(drop_kind):
		label = str(DROP_ITEMS[drop_kind][0])
	print("Sindi -> ", amount, " ta ", label)


# =========================================================================
#  URISH BO'LAKLARI (chips) — har urishda obyektdan sakrab chiqadi
# =========================================================================

# kind: "tree" (jigarrang yog'och parchasi) yoki "rock" (kulrang tosh parchasi)
func _spawn_hit_chips(cell: Vector2i, kind: String) -> void:
	var base := grid_to_local(cell.x, cell.y)
	var n := randi_range(3, 5)
	for i in range(n):
		var ang := randf() * TAU
		var sp := randf_range(25.0, 55.0)
		var col: Color
		if kind == "rock":
			# Tosh parchalari — kulrang, ba'zisi ochroq
			var g := randf_range(0.42, 0.68)
			col = Color(g, g, g * 1.05, 1.0)
		else:
			# Yog'och parchalari — jigarrang
			col = Color(randf_range(0.38, 0.52), randf_range(0.24, 0.34), 0.15, 1.0)
		hit_chips.append({
			"pos": base + Vector2(0.0, -6.0),
			"vel": Vector2(cos(ang), sin(ang)) * sp,
			"z": randf_range(4.0, 10.0),
			"zvel": randf_range(35.0, 70.0),
			"life": randf_range(0.45, 0.75),
			"size": randf_range(1.6, 3.2),
			"color": col,
		})


func _update_chips(delta: float) -> void:
	if hit_chips.is_empty():
		return
	var g := 200.0
	var alive := []
	for c in hit_chips:
		c["life"] -= delta
		if c["life"] <= 0.0:
			continue
		c["z"] += c["zvel"] * delta
		c["zvel"] -= g * delta
		c["pos"] += c["vel"] * delta
		c["vel"] *= 0.90
		if c["z"] < 0.0:
			c["z"] = 0.0
			c["zvel"] = -c["zvel"] * 0.35   # yerdan sakraydi
			c["vel"] *= 0.6
		alive.append(c)
	hit_chips = alive


func _draw_chips() -> void:
	for c in hit_chips:
		var a: float = clampf(c["life"] / 0.4, 0.0, 1.0)
		var col: Color = c["color"]
		col.a = a
		var s: float = c["size"]
		var p: Vector2 = c["pos"] - Vector2(0.0, c["z"])
		draw_rect(Rect2(p - Vector2(s / 2.0, s / 2.0), Vector2(s, s)), col)


# Barcha uchib/yotgan resurslarni chizadi.
# O'tin kichkina Minecraft-uslubidagi item bo'lib ko'rinadi.
var _white_cache := {}   # Texture2D -> oq siluet (drops konturi uchun)

# Berilgan tekstura uchun OQ siluetni qaytaradi (keshlangan)
func _white_for(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _white_cache.has(tex):
		return _white_cache[tex]
	var w := _make_white(tex)
	_white_cache[tex] = w
	return w


func _draw_all_wood() -> void:
	for item in wood_items:
		var kind: String = item.get("kind", "wood")
		var draw_size := WOOD_DROP_SIZE
		var tex_to_use: Texture2D = null

		if kind == "wood" or kind == "stump_wood":
			if _wood_drop_texture == null:
				continue
			tex_to_use = _wood_drop_texture
		elif kind == "palm":
			if _palm_drop_texture == null:
				continue
			tex_to_use = _palm_drop_texture
			draw_size = Vector2(13.0, 12.0)
		elif kind == "cactus":
			if _cactus_drop_texture == null:
				continue
			tex_to_use = _cactus_drop_texture
			draw_size = Vector2(13.0, 13.0)
		elif kind == "gold":
			if not _icons.has("gold_ore"):
				continue
			tex_to_use = _icons["gold_ore"]
			draw_size = Vector2(12.0, 12.0)
		elif kind == "gem":
			if not _icons.has("sapphire"):
				continue
			tex_to_use = _icons["sapphire"]
			draw_size = Vector2(12.0, 12.0)
		elif kind == "grass":
			if not _icons.has("item_grass"):
				continue
			tex_to_use = _icons["item_grass"]
			draw_size = Vector2(13.0, 13.0)
		elif kind == "wheat":
			if not _icons.has("item_wheat"):
				continue
			tex_to_use = _icons["item_wheat"]
			draw_size = Vector2(13.0, 13.0)
		else:
			if _rock_data.is_empty():
				continue
			var rinfo = _rock_data[0]
			tex_to_use = rinfo["tex"]
			draw_size = STONE_DROP_SIZE

		if tex_to_use == null:
			continue

		# z balandligi: item sakraganda yuqoriga ko'tariladi.
		var draw_pos: Vector2 = Vector2(item["pos"]) - Vector2(draw_size.x / 2.0, draw_size.y) - Vector2(0.0, float(item["z"]))

		# OQ KONTUR — yerda yotgan itemlar ajralib tursin (ISO-CORE kabi)
		var wtex: Texture2D = _white_for(tex_to_use)
		if wtex != null:
			for off in OUTLINE_OFFSETS:
				draw_texture_rect(wtex, Rect2(draw_pos + off, draw_size), false)

		# Yerga tushganda kichik soya.
		var shadow_r := maxf(2.5, 5.0 - float(item["z"]) * 0.04)
		draw_circle(
			item["pos"] + Vector2(0, 2),
			shadow_r,
			Color(0, 0, 0, 0.22)
		)

		draw_texture_rect(
			tex_to_use,
			Rect2(draw_pos, draw_size),
			false
		)


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
	var w: float = float(tex.get_width()) * PLAYER_DRAW_SCALE
	var h: float = float(tex.get_height()) * PLAYER_DRAW_SCALE

	# Turgan katakning terrasa balandligi — personaj yer ustida tursin
	var _pcell := local_to_grid(player.position)
	var plift := _lift_px(_pcell.x, _pcell.y)

	# Sakrash balandligi (SPACE bosilganda ko'tariladi) + terrasa ko'tarilishi
	var draw_pos := player.position - Vector2(0.0, jump_z + plift)

	# Suzayaptimi? (suv ustida) — bo'lsa quyosh soyasi o'rniga to'lqin chiziladi
	var in_water: bool = _ground_type(_pcell.x, _pcell.y) == "water"

	# Quyosh soyasi — kunduzi, daraxtlar bilan bir xil yo'nalishda.
	# Sakraganda soya joyida qoladi (personaj havoda). Suvda soya chizilmaydi.
	var day: float = _daylight()
	if day > 0.02 and not in_water:
		var shear: float = _sun_shear()
		# Sakraganda soya kichrayadi (uzoqlashgandek)
		var jshrink: float = clampf(1.0 - jump_z * 0.012, 0.55, 1.0)
		var sw: float = w * jshrink
		var sh: float = h * jshrink
		var m := Transform2D(Vector2(1.0, 0.0),
			Vector2(shear, SHADOW_SQUASH),
			player.position + Vector2(0.0, 3.0 - plift))
		draw_set_transform_matrix(m)
		# Personaj sprite'ining o'zini qora qilib chizamiz
		draw_texture_rect(tex, Rect2(Vector2(-sw / 2.0, -sh), Vector2(sw, sh)),
			false, Color(0.0, 0.0, 0.0, SHADOW_ALPHA * day * 0.85))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	if spr.flip_h:
		# FLIP + bir oz kattaroq personaj.
		draw_set_transform(draw_pos, 0.0, Vector2(-PLAYER_DRAW_SCALE, PLAYER_DRAW_SCALE))
		draw_texture(tex, -Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(draw_pos, 0.0, Vector2(PLAYER_DRAW_SCALE, PLAYER_DRAW_SCALE))
		draw_texture(tex, -Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ---- SUZISH: pastki qism suv ostida (tanani ko'kimtir bosadi) + to'lqin ----
	if in_water:
		var body_w: float = w * 0.62
		var submerge_h: float = h * 0.40   # tananing pastki 40% i suv ostida
		var wtop: float = draw_pos.y - submerge_h * 0.55
		var wrect := Rect2(draw_pos.x - body_w / 2.0, wtop, body_w, submerge_h)
		draw_rect(wrect, Color(0.35, 0.62, 0.78, 0.55))
		# Yuzadagi to'lqin chizig'i (sekin pulslab kengayadi)
		var ripple: float = 0.5 + 0.5 * sin(_beacon_t * 3.0)
		var rw: float = body_w * (0.9 + 0.3 * ripple)
		draw_arc(Vector2(draw_pos.x, wtop), rw / 2.0, 0.0, PI, 10,
			Color(0.85, 0.95, 1.0, 0.35 * (1.0 - ripple * 0.5)), 2.0)
		# Kichik pufakchalar
		draw_circle(Vector2(draw_pos.x - body_w * 0.25, wtop + 4.0), 1.6, Color(0.9, 0.97, 1.0, 0.5))
		draw_circle(Vector2(draw_pos.x + body_w * 0.22, wtop + 7.0), 1.2, Color(0.9, 0.97, 1.0, 0.4))


# LAN: boshqa o'yinchilarni chizadi
func _draw_net_players() -> void:
	if not net_active or net_peers.is_empty() or player == null:
		return
	var spr := player as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return
	var font := ThemeDB.fallback_font
	for pid in net_peers.keys():
		var st: Dictionary = net_peers[pid]
		var ppos: Vector2 = st.get("pos", Vector2.ZERO)
		var an: String = str(st.get("anim", "idle_Down"))
		if not spr.sprite_frames.has_animation(an):
			an = "idle_Down"
			if not spr.sprite_frames.has_animation(an):
				continue
		var cnt := spr.sprite_frames.get_frame_count(an)
		if cnt <= 0:
			continue
		var fr: int = clampi(int(st.get("frame", 0)), 0, cnt - 1)
		var tex := spr.sprite_frames.get_frame_texture(an, fr)
		if tex == null:
			continue
		var fl: bool = bool(st.get("flip", false))
		var sx: float = -PLAYER_DRAW_SCALE if fl else PLAYER_DRAW_SCALE
		draw_set_transform(ppos, 0.0, Vector2(sx, PLAYER_DRAW_SCALE))
		draw_texture(tex, -Vector2(tex.get_width() / 2.0, tex.get_height() / 2.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Ism yorlig'i
		var nm := "P" + str(pid)
		var nw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, ppos + Vector2(-nw / 2.0, -34.0), nm,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 1.0))


# Hayvon (slime) personajga zarba bersa chaqiriladi -> jon kamayadi
func hurt_player(amount: int) -> void:
	if _hurt_cooldown > 0.0 or amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	_hurt_cooldown = 0.8            # qisqa himoya — birdaniga tugab qolmasin
	play_sfx("hit_stone", -4.0, 0.15)
	if player != null and player.has_method("do_action"):
		player.do_action("damage")
	if hud_node != null:
		hud_node.queue_redraw()
	if health <= 0:
		_respawn_player()


func _respawn_player() -> void:
	health = MAX_HEALTH
	_hurt_cooldown = 1.5
	if player != null and last_player_safe_pos != Vector2.ZERO:
		player.position = last_player_safe_pos
	show_hint("Qaytadan tiriltirilding", 2.0)
	if hud_node != null:
		hud_node.queue_redraw()


# Bosilgan joy yaqinida hayvon (hit metodi bor) bo'lsa uradi.
# Qo'l/qilich/bolta/kirka — HAR QANDAY narsa bilan urish mumkin.
func _attack_nearby_animal(cell: Vector2i) -> bool:
	if player == null or animals.is_empty():
		return false
	var click_pos := grid_to_local(cell.x, cell.y)
	var best = null
	var best_d := 1e9
	for a in animals:
		if not is_instance_valid(a) or not a.has_method("hit"):
			continue
		var d: float = a.position.distance_to(click_pos)
		if d < 30.0 and d < best_d:
			best = a
			best_d = d
	if best == null:
		return false

	# Yetib bormasa — avval yaqinlashamiz
	if player.position.distance_to(best.position) > 54.0:
		_last_path_target = Vector2i(999999, 999999)
		_walk_player_to_cell(local_to_grid(best.position), true)
		return true

	# Zarar: QO'L bilan 1 (slime 5 marta), har qanday ASBOB bilan 2 (slime 3 marta).
	var eq := get_equipped()
	var dmg := 2 if is_tool(eq) else 1

	if player.has_method("face_point"):
		player.face_point(best.position)
	if player.has_method("do_action"):
		var swing := "sword_attack" if (eq == "Qilich" or eq == "Sehrli qilich") else "swing"
		player.do_action(swing)
	best.hit(dmg)
	play_sfx("hit_stone", -6.0, 0.2)
	return true


# Hayvon kadrining OQ versiyasi (hover konturi uchun), keshlanadi
func _anim_white(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _anim_white_cache.has(tex):
		return _anim_white_cache[tex]
	if _anim_white_cache.size() > 400:
		_anim_white_cache.clear()
	var w := _make_white(tex)
	_anim_white_cache[tex] = w
	return w


# Bitta hayvonni chuqurlik bo'yicha, personaj kabi, dunyo _draw() ichida chizadi.
# Shunda oldindagi daraxt/tosh uni to'sadi (va shaffof bo'lib orqasidan ko'rinadi).
func _draw_animal_sprite(a) -> void:
	var spr := a as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return
	var anim := str(spr.animation)
	if not spr.sprite_frames.has_animation(anim):
		return
	var tex := spr.sprite_frames.get_frame_texture(anim, spr.frame)
	if tex == null:
		return
	var sc := spr.scale
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var center := spr.position + spr.offset

	# Hover — sichqoncha shu hayvon ustidami? (markazidan ~20px)
	var mouse_local := get_local_mouse_position()
	var hovered: bool = mouse_local.distance_to(spr.position) < 20.0

	draw_set_transform(center, 0.0, Vector2(-sc.x if spr.flip_h else sc.x, sc.y))
	var dst := Rect2(-Vector2(tw * 0.5, th * 0.5), Vector2(tw, th))
	if hovered:
		var wtex := _anim_white(tex)
		if wtex != null:
			for off in OUTLINE_OFFSETS:
				draw_texture_rect(wtex, Rect2(dst.position + off, dst.size), false, Color(1, 1, 1, 1))
	draw_texture_rect(tex, dst, false, spr.modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Hayvonlarni personaj atrofida paydo qiladi va uzoqdagilarni olib tashlaydi
func _update_animals() -> void:
	if player == null or _animal_scenes.is_empty():
		return

	# 1) Uzoqlashganlarni olib tashlaymiz
	var alive := []
	for a in animals:
		if not is_instance_valid(a):
			continue
		if a.position.distance_to(player.position) > DESPAWN_DIST:
			a.queue_free()
		else:
			alive.append(a)
	animals = alive

	# 2) Kam bo'lsa — yangi paydo qilamiz
	if animals.size() >= MAX_ANIMALS:
		return

	# Bir tekshiruvda faqat 1 ta paydo qilamiz (birdaniga to'lib ketmasin)
	for i in range(1):
		if animals.size() >= MAX_ANIMALS:
			break
		var spot = _find_spawn_spot()
		if spot == null:
			continue
		var scene = _animal_scenes[randi() % _animal_scenes.size()]
		var animal = scene.instantiate()
		animal.position = spot
		animal.visible = false          # dunyo _draw() ichida chuqurlik bo'yicha chiziladi
		add_child(animal)
		animals.append(animal)


# Personajdan uzoqda, quruqlikda, MAVJUD hayvonlardan tarqoq bo'sh joy topadi
func _find_spawn_spot():
	for attempt in range(24):
		var angle = randf() * TAU
		var dist = randf_range(SPAWN_MIN_DIST, SPAWN_MAX_DIST)
		var p = player.position + Vector2(cos(angle), sin(angle)) * dist
		var cell = local_to_grid(p)
		# Suvda hayvon spawn qilmaymiz.
		var ground := _ground_type(cell.x, cell.y)
		if ground == "water":
			continue
		var deco = _decor_at(cell.x, cell.y)
		if deco == "tree" or deco == "cactus" or deco == "rock":
			continue
		# Boshqa hayvonlardan uzoq bo'lsin (bitta joyda to'planmasin)
		var too_close := false
		for a in animals:
			if is_instance_valid(a) and a.position.distance_to(p) < SPAWN_APART:
				too_close = true
				break
		if too_close:
			continue
		return p
	return null


# Ovoz chaladi (bo'sh kanalni topib)
# pitch: ovoz balandligi (1.0 = normal). Har safar ozgina o'zgartirsak
# takrorlanish zerikarli bo'lmaydi.
func play_sfx(name: String, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not _sfx.has(name) or _sfx_players.is_empty():
		return
	var p = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = _sfx[name]
	# Settings > Sound > World SFX slayderi
	p.volume_db = volume_db + linear_to_db(maxf(0.0001, Lang.vol_sfx))
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


# =========================================================================
#  ASBOBLAR
# =========================================================================

# Tutorial: "Tushundim" bosilganda keyingi kartaga o'tadi.
# Hozirgi karta CHIQISHI kerakmi? (o'z trigger sharti bajarilganda)
func _tutorial_should_show() -> bool:
	if not tutorial_active:
		return false
	if tutorial_index >= tutorials.size():
		return false
	var trig := str(tutorials[tutorial_index].get("trigger", "start"))
	match trig:
		"start":
			return true
		"moved":
			return _tut_moved
		"near_tree":
			return _tut_near_tree()
		"wood":
			return count_item("Yog'och") > 0
		"opened_inv":
			return _tut_opened_inv
		"crafted":
			return crafted.size() > 0
		"time":
			return _tut_time > 25.0
		_:
			return true


# Personaj yaqinida (5x5) daraxt/tosh bormi?
func _tut_near_tree() -> bool:
	if player == null:
		return false
	var pc := local_to_grid(player.position)
	for dc in range(-4, 5):
		for dr in range(-4, 5):
			var d := _decor_at(pc.x + dc, pc.y + dr)
			if d == "tree" or d == "cactus" or d == "rock":
				return true
	return false


# SettingsPanel qaytargan action'ni bajaradi.
# Video/ovoz/til/boshqaruvni panelning o'zi Lang ichida hal qiladi —
# bu yerda faqat O'YINGA tegishli buyruqlar qoladi.
func _settings_action(action: String) -> void:
	match action:
		"volumes":
			apply_volumes()
		"close":
			settings_open = false
		"save_game":
			if save_game():
				show_hint(Lang.t("hint.saved"), 2.0)
			else:
				show_hint(Lang.t("hint.save_failed"), 2.5)
		"return_title":
			save_game()                 # chiqishdan oldin avtomatik saqlaymiz
			get_tree().change_scene_to_file("res://main_menu.tscn")
		"quit":
			save_game()
			get_tree().quit()
		"net_host":
			net_host()
		"net_join":
			typing_ip = false
			settings_panel.typing_ip = false
			net_join(join_ip)
		"net_off":
			net_disconnect()
		"type_ip":
			typing_ip = settings_panel.typing_ip
			if typing_ip:
				join_ip = ""
	queue_redraw()


# Berilgan nom uchun ikonka topadi (RECIPES/ANVIL/MAGIC dan qidiradi)
func _icon_for_item(item_name: String) -> String:
	for rec_list in [RECIPES, ANVIL_RECIPES, MAGIC_RECIPES]:
		for r in rec_list:
			if str(r.get("name", "")) == item_name:
				return str(r.get("icon", ""))
	# Ba'zi item ikonkalari to'g'ridan _icons da bor bo'lishi mumkin
	if _icons.has(item_name):
		return item_name
	return ""


# Berilgan nom uchun retseptni topadi (bo'sh Dictionary = topilmadi)
func _recipe_for_item(item_name: String) -> Dictionary:
	for rec_list in [RECIPES, ANVIL_RECIPES, MAGIC_RECIPES]:
		for r in rec_list:
			if str(r.get("name", "")) == item_name:
				return r
	return {}


func _tutorial_advance() -> void:
	tutorial_index += 1
	if tutorial_index >= tutorials.size():
		tutorial_active = false
		var f := FileAccess.open(TUTORIAL_SAVE, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
			f.close()
	queue_redraw()


# Hotbar'da tanlangan katakdagi narsa nomi ("" = bo'sh / qo'l bilan)
func get_equipped() -> String:
	if selected_slot < inv.size() and inv[selected_slot] != null:
		return inv[selected_slot]["name"]
	return ""


# =========================================================================
# ASBOB ZARARI
# =========================================================================

# Qo'ldagi narsa HAQIQIY ASBOBMI?
# Yog'och, tosh, Anvil kabi narsalar asbob emas — qo'l bilan barobar.
func is_tool(item_name: String) -> bool:
	return item_name == "Bolta" or item_name == "Kirka" \
		or item_name == "Belkurak" or item_name == "Qilich"


# Qaysi asbob nimani ola oladi:
#   Daraxt / Kaktus -> qo'l yoki Bolta
#   Tosh            -> qo'l yoki Kirka
#   Yer (blok)      -> faqat Belkurak
func can_harvest(kind: String) -> bool:
	var eq := get_equipped()
	if not is_tool(eq):
		eq = ""
	match kind:
		"tree", "cactus", "grasstuft":
			return eq == "" or eq == "Bolta"
		"rock":
			return eq == "" or eq == "Kirka"
		"ground":
			return eq == "Belkurak"
		_:
			return false


# Chap yuqori burchakdagi kichkina ogohlantirish
# Item olinganda o'ng chetda kichik bildirishnoma chiqaradi.
# Bir xil nom qisqa vaqt ichida qayta kelsa -> sonni oshirib, taymerni yangilaydi.
func _toast(item_name: String, icon: String, amount: int = 1) -> void:
	if toasts.size() > 0:
		var top: Dictionary = toasts[0]
		if str(top.get("name", "")) == item_name and float(top.get("timer", 0.0)) > 0.0:
			top["count"] = int(top["count"]) + amount
			top["timer"] = TOAST_LIFE
			return
	toasts.push_front({"name": item_name, "icon": icon, "count": amount, "timer": TOAST_LIFE})
	if toasts.size() > 5:
		toasts.resize(5)


func _update_toasts(delta: float) -> void:
	if toasts.is_empty():
		return
	var alive := []
	for t in toasts:
		t["timer"] = float(t["timer"]) - delta
		if float(t["timer"]) > -0.5:   # so'nish animatsiyasi uchun ozgina qo'shimcha vaqt
			alive.append(t)
	toasts = alive


func show_hint(text: String, seconds: float = 1.8) -> void:
	if text == "":
		return
	hint_text = text
	hint_timer = seconds


func harvest_hint(kind: String) -> String:
	var eq := get_equipped()
	if not is_tool(eq):
		eq = ""
	match kind:
		"tree", "cactus", "stump":
			if eq == "":
				return ""
			return Lang.n(eq) + " " + Lang.t("hint.need_axe")
		"rock":
			if eq == "":
				return ""
			return Lang.n(eq) + " " + Lang.t("hint.need_pick")
		"ground":
			return Lang.t("hint.need_shovel")
		_:
			return ""


# Bir urishda qancha zarar.
# Qo'l bilan 1 (sekin), to'g'ri asbob bilan 2 (ikki barobar tez).
func get_tool_damage(kind: String) -> int:
	var eq := str(get_equipped()).strip_edges().to_lower()

	if kind == "tree" or kind == "cactus" or kind == "stump":
		if eq == "bolta" or eq == "axe" or eq == "sehrli bolta":
			return 2
		return 1

	if kind == "rock":
		if eq == "kirka" or eq == "pickaxe" or eq == "sehrli kirka":
			return 2
		return 1

	return 1

# To'g'ri asbob bilan qo'shimcha resurs
func get_tool_bonus(kind: String) -> int:
	var eq = get_equipped()
	if TOOLS.has(eq) and TOOLS[eq]["good_for"] == kind:
		return TOOLS[eq]["bonus"]
	return 0


# =========================================================================
#  INVENTAR
# =========================================================================

# Narsani inventarga qo'shadi (bor bo'lsa ustiga qo'shiladi)
func add_item(item_name: String, icon: String, amount: int = 1) -> bool:
	# 1) Shu nomdagi katak bormi — ustiga qo'shamiz
	for i in range(inv.size()):
		if inv[i] != null and inv[i]["name"] == item_name:
			# Cheksiz narsaga qo'shishning ma'nosi yo'q
			if inv[i].get("infinite", false):
				return true
			inv[i]["count"] += amount
			return true
	# 2) Bo'sh katak topamiz
	for i in range(inv.size()):
		if inv[i] == null:
			inv[i] = {"name": item_name, "icon": icon, "count": amount}
			return true
	print("Inventar to'la!")
	return false


# Shu nomdagi narsa jami nechta
func count_item(item_name: String) -> int:
	var total = 0
	for slot in inv:
		if slot != null and slot["name"] == item_name:
			if slot.get("infinite", false):
				return 9999
			total += slot["count"]
	return total


# Tanlangan HOTBAR katagidan bitta sarflaydi.
# (remove_item ism bo'yicha qidirardi -> inventardagi CHEKSIZ manbani
#  topib, hotbardagi nusxani sarflamasdan qo'yaverardi.)
func consume_equipped(amount: int = 1) -> bool:
	if selected_slot < 0 or selected_slot >= inv.size():
		return false
	var slot = inv[selected_slot]
	if slot == null:
		return false
	# Cheksiz manba tanlangan bo'lsa — kamaymaydi
	if bool(slot.get("infinite", false)):
		return true
	if int(slot["count"]) < amount:
		return false
	slot["count"] = int(slot["count"]) - amount
	if int(slot["count"]) <= 0:
		inv[selected_slot] = null
	return true


# Narsani inventardan olib tashlaydi
func remove_item(item_name: String, amount: int) -> bool:
	# CHEKSIZ narsa (masalan Yasash stoli) — hech qachon kamaymaydi
	for slot in inv:
		if slot != null and slot["name"] == item_name and slot.get("infinite", false):
			return true
	if count_item(item_name) < amount:
		return false
	var left = amount
	for i in range(inv.size()):
		if inv[i] != null and inv[i]["name"] == item_name:
			var take = min(left, inv[i]["count"])
			inv[i]["count"] -= take
			left -= take
			if inv[i]["count"] <= 0:
				inv[i] = null
			if left <= 0:
				return true
	return true


# =========================================================================
#  SANDIQ (CHEST) — ombor
# =========================================================================

# Yangi bo'sh sandiq ombori
func _new_chest_storage() -> Array:
	var a := []
	a.resize(CHEST_SIZE)
	for i in range(CHEST_SIZE):
		a[i] = null
	return a


# Hozir ochiq sandiqning ombori (yoki null)
func get_open_chest():
	if not chest_open:
		return null
	if not chests.has(open_chest_cell):
		return null
	return chests[open_chest_cell]


# Yaqindagi sandiqni topadi
func _find_nearby_chest() -> Vector2i:
	if player == null:
		return Vector2i(999999, 999999)
	var best := Vector2i(999999, 999999)
	var best_d := INF
	for cell in chests.keys():
		var c: Vector2i = cell
		var p := grid_to_local(c.x, c.y)
		var d := player.position.distance_to(p)
		if d <= CHEST_REACH and d < best_d:
			best_d = d
			best = c
	return best


# Sandiq bo'shmi? (qaytarib olishdan oldin tekshiramiz)
func _chest_is_empty(cell: Vector2i) -> bool:
	if not chests.has(cell):
		return true
	for s in chests[cell]:
		if s != null:
			return false
	return true


# Narsani sandiqqa qo'shadi (bor bo'lsa ustiga)
func _chest_add(store: Array, item_name: String, icon: String, amount: int) -> bool:
	for i in range(store.size()):
		if store[i] != null and store[i]["name"] == item_name:
			store[i]["count"] += amount
			return true
	for i in range(store.size()):
		if store[i] == null:
			store[i] = {"name": item_name, "icon": icon, "count": amount}
			return true
	return false


# INVENTAR -> SANDIQ (butun to'plam)
func chest_put(inv_idx: int) -> void:
	var store = get_open_chest()
	if store == null:
		return
	if inv_idx < 0 or inv_idx >= inv.size() or inv[inv_idx] == null:
		return
	var it = inv[inv_idx]
	if _chest_add(store, it["name"], it["icon"], int(it["count"])):
		inv[inv_idx] = null
		play_sfx("collect", -10.0, 0.1)
	else:
		show_hint(Lang.t("hint.chest_full"))
		play_sfx("fail", -9.0, 0.0)
	_refresh_counts()


# SANDIQ -> INVENTAR (butun to'plam)
func chest_take(chest_idx: int) -> void:
	var store = get_open_chest()
	if store == null:
		return
	if chest_idx < 0 or chest_idx >= store.size() or store[chest_idx] == null:
		return
	var it = store[chest_idx]
	if add_item(it["name"], it["icon"], int(it["count"])):
		store[chest_idx] = null
		play_sfx("collect", -10.0, 0.1)
	else:
		show_hint(Lang.t("hint.inv_full"))
		play_sfx("fail", -9.0, 0.0)
	_refresh_counts()


func _refresh_counts() -> void:
	wood_count = count_item("Yog'och")
	stone_count = count_item("Tosh")
	queue_redraw()


# Retsept bo'yicha narsa yasaydi (resurs yetsa)
# KILN: retseptni tanlab pishirishni boshlaydi (resurs bo'lsa).
# Vaqt o'tib pishgach "ready" oshadi, keyin "collect" bilan olinadi.
func _kiln_start(idx: int) -> void:
	if open_kiln_cell == Vector2i(999999, 999999):
		return
	if idx < 0 or idx >= KILN_RECIPES.size():
		return
	kiln_selected = idx
	var r: Dictionary = KILN_RECIPES[idx]
	var job = kiln_jobs.get(open_kiln_cell, null)
	# Boshqa retsept pishayotgan bo'lsa, avval uni tugatish kerak
	if job != null and int(job.get("recipe", -1)) != idx and float(job.get("elapsed", 0.0)) > 0.0:
		show_hint("Avval joriy pishirishni yakunlang")
		return
	var need_w := int(r.get("wood", 0))
	var need_s := int(r.get("stone", 0))
	var need_g := int(r.get("gold", 0))
	if count_item("Yog'och") < need_w or count_item("Tosh") < need_s or count_item("Oltin") < need_g:
		play_sfx("fail", -8.0, 0.0)
		return
	var ready: int = int(job.get("ready", 0)) if job != null else 0
	if ready >= KILN_MAX_READY:
		show_hint("Kiln to'la — avval yig'ib oling")
		return
	if need_w > 0: remove_item("Yog'och", need_w)
	if need_s > 0: remove_item("Tosh", need_s)
	if need_g > 0: remove_item("Oltin", need_g)
	kiln_jobs[open_kiln_cell] = {"recipe": idx, "elapsed": 0.0,
		"duration": float(r.get("time", 5.0)), "ready": ready}
	play_sfx("craft", -8.0, 0.05)
	queue_redraw()


# Tayyor bo'lgan mahsulotni inventarga yig'ib oladi
func _kiln_collect() -> void:
	if open_kiln_cell == Vector2i(999999, 999999):
		return
	var job = kiln_jobs.get(open_kiln_cell, null)
	if job == null:
		return
	var ready: int = int(job.get("ready", 0))
	if ready <= 0:
		return
	var r: Dictionary = KILN_RECIPES[int(job["recipe"])]
	if add_item(str(r["name"]), str(r["icon"]), ready):
		crafted[str(r["name"])] = int(crafted.get(str(r["name"]), 0)) + ready
		_toast(str(r["name"]), str(r["icon"]), ready)
		job["ready"] = 0
		play_sfx("collect", -6.0, 0.1)
		queue_redraw()
	else:
		show_hint("Inventar to'la")


# Barcha kilnlarni har kadr yangilaydi — panel yopiq bo'lsa ham pishayveradi
func _update_kilns(delta: float) -> void:
	if kiln_jobs.is_empty():
		return
	for cell in kiln_jobs.keys():
		var job: Dictionary = kiln_jobs[cell]
		var ready: int = int(job.get("ready", 0))
		if ready >= KILN_MAX_READY:
			continue
		var dur: float = float(job.get("duration", 5.0))
		if dur <= 0.0:
			continue
		job["elapsed"] = float(job.get("elapsed", 0.0)) + delta
		if float(job["elapsed"]) >= dur:
			job["elapsed"] = 0.0
			job["ready"] = ready + 1
			# Avtomatik davom etadi — agar resurs yetsa, keyingisini o'zi boshlaydi
			var ridx: int = int(job["recipe"])
			if ridx >= 0 and ridx < KILN_RECIPES.size() and int(job["ready"]) < KILN_MAX_READY:
				var r: Dictionary = KILN_RECIPES[ridx]
				var nw := int(r.get("wood", 0)); var ns := int(r.get("stone", 0)); var ng := int(r.get("gold", 0))
				if count_item("Yog'och") >= nw and count_item("Tosh") >= ns and count_item("Oltin") >= ng:
					if nw > 0: remove_item("Yog'och", nw)
					if ns > 0: remove_item("Tosh", ns)
					if ng > 0: remove_item("Oltin", ng)
				# resurs yetmasa ham "ready" saqlanadi, elapsed 0 da to'xtab qoladi
		queue_redraw()


func _try_craft(idx: int) -> void:
	if idx < 0 or idx >= RECIPES.size():
		return
	var r = RECIPES[idx]
	craft_selected = idx
	wood_count = count_item("Yog'och")
	stone_count = count_item("Tosh")
	if wood_count < r["wood"] or stone_count < r["stone"]:
		print("Resurs yetmaydi: ", r["name"],
			" (kerak: ", r["wood"], " yog'och, ", r["stone"], " tosh)")
		play_sfx("fail", -8.0, 0.0)
		return
	remove_item("Yog'och", r["wood"])
	remove_item("Tosh", r["stone"])
	wood_count = count_item("Yog'och")
	stone_count = count_item("Tosh")
	# Yasalgan narsa inventarga tushadi
	add_item(r["name"], r["icon"], 1)
	var n = crafted.get(r["name"], 0) + 1
	crafted[r["name"]] = n
	print("Yasaldi: ", r["name"], " x", n)
	play_sfx("craft", -6.0, 0.03)

func _try_magic_craft(idx: int) -> void:
	if idx < 0 or idx >= MAGIC_RECIPES.size():
		return
	var r: Dictionary = MAGIC_RECIPES[idx]
	magic_selected = idx
	var wn := int(r.get("wood", 0))
	var sn := int(r.get("stone", 0))
	var cn := int(r.get("copper", 0))
	if count_item("Yog'och") < wn or count_item("Tosh") < sn or count_item("Mis") < cn:
		play_sfx("fail", -8.0, 0.0)
		return
	if wn > 0: remove_item("Yog'och", wn)
	if sn > 0: remove_item("Tosh", sn)
	if cn > 0: remove_item("Mis", cn)
	add_item(r["name"], r["icon"], 1)
	crafted[r["name"]] = int(crafted.get(r["name"], 0)) + 1
	play_sfx("craft", -6.0, 0.03)
	queue_redraw()


func _try_anvil_craft(idx: int) -> void:
	if idx < 0 or idx >= ANVIL_RECIPES.size():
		return
	var r: Dictionary = ANVIL_RECIPES[idx]
	anvil_selected = idx
	var wn := int(r.get("wood", 0))
	var sn := int(r.get("stone", 0))
	if count_item("Yog'och") < wn or count_item("Tosh") < sn:
		play_sfx("fail", -8.0, 0.0)
		return
	if wn > 0: remove_item("Yog'och", wn)
	if sn > 0: remove_item("Tosh", sn)
	add_item(r["name"], r["icon"], 1)
	crafted[r["name"]] = int(crafted.get(r["name"], 0)) + 1
	play_sfx("craft", -6.0, 0.03)
	queue_redraw()


# Yomg'ir tomchilarini har kadr pastga tushiradi
func _update_rain(delta: float) -> void:
	var vp = get_viewport_rect().size
	# Kerakli sonda tomchi bo'lsin
	while rain_drops.size() < RAIN_COUNT:
		rain_drops.append({
			"pos": Vector2(randf() * (vp.x + 200.0) - 100.0, randf() * vp.y),
			"speed": randf_range(700.0, 1100.0),
			"len": randf_range(10.0, 20.0),
		})
	for d in rain_drops:
		# Yomg'ir ozgina qiya tushadi
		d["pos"] += Vector2(-90.0, d["speed"]) * delta
		if d["pos"].y > vp.y:
			d["pos"] = Vector2(randf() * (vp.x + 200.0) - 100.0, -20.0)
		elif d["pos"].x < -120.0:
			d["pos"] = Vector2(vp.x + randf() * 100.0, randf() * vp.y)


# =========================================================================
#  SOYA
# =========================================================================

# Soya qay tomonga va qancha cho'zilgan.
#   time_of_day 0.25 (tong)  -> +1.25  (soya CHAPGA, uzun)
#   time_of_day 0.50 (tush)  ->  0     (soya qisqa, tik)
#   time_of_day 0.75 (kech)  -> -1.25  (soya O'NGGA, uzun)
func _sun_shear() -> float:
	return SHADOW_MAX_SHEAR * cos(TAU * (time_of_day - 0.25))


# Kunduzi 1.0, tunda 0.0 — soya tunda umuman chizilmaydi.
func _daylight() -> float:
	# 0.18 (tong otishi) .. 0.82 (qorong'i tushishi)
	if time_of_day < 0.18 or time_of_day > 0.82:
		return 0.0
	return clampf(sin(PI * (time_of_day - 0.18) / 0.64), 0.0, 1.0)


# Oq siluetni QORA qilib, yassilashtirib va qiyshaytirib chizadi.
# base = obyektning yerga tegib turgan nuqtasi.
func _draw_shadow(white_tex: Texture2D, base: Vector2, dw: float, dh: float) -> void:
	if white_tex == null:
		return
	var day := _daylight()
	if day <= 0.02:
		return

	# Tush paytida soya quyuqroq va kalta, kech/tongda uzun va och.
	var shear := _sun_shear()
	var a: float = SHADOW_ALPHA * day

	# y_axis ni qiyshaytiramiz -> rasmning TEPASI yon tomonga og'adi,
	# pasti esa joyida qoladi (haqiqiy soya shunday tushadi).
	var m := Transform2D(Vector2(1.0, 0.0), Vector2(shear, SHADOW_SQUASH), base)
	draw_set_transform_matrix(m)
	# Oq siluet x qora rang = qora siluet (modulate ko'paytiradi)
	draw_texture_rect(white_tex, Rect2(Vector2(-dw / 2.0, -dh), Vector2(dw, dh)),
		false, Color(0.0, 0.0, 0.0, a))
	draw_set_transform_matrix(Transform2D.IDENTITY)


# Katakning yerga tegish nuqtasi (soya shu yerdan boshlanadi)
func _shadow_base(col: int, row: int) -> Vector2:
	return grid_to_local(col, row) + Vector2(0.0, TILE_H / 2.0 - _lift_px(col, row))


# ---- Har tur uchun soya ----
func _draw_tree_shadow(col: int, row: int) -> void:
	var info = _get_tree_info_at(col, row)
	if info == null:
		return
	var fh := float(info["fh"])
	var fw := float(info["fw"])
	var my_max_h: float = float(info.get("max_h", TREE_MAX_HEIGHT))
	var s := minf(1.0, my_max_h / fh)
	_draw_shadow(info.get("white", null), _shadow_base(col, row), fw * s, fh * s)


func _draw_rock_shadow(col: int, row: int) -> void:
	if _rock_data.is_empty():
		return
	var info = _rock_data[_stable_index(col, row, 11, _rock_data.size())]
	var fh := float(info["fh"])
	var fw := float(info["fw"])
	var s := minf(1.0, ROCK_MAX_HEIGHT / fh)
	_draw_shadow(info.get("white", null), _shadow_base(col, row), fw * s, fh * s)


func _draw_stump_shadow(cell: Vector2i) -> void:
	if stump_texture == null or stump_white == null:
		return
	var fh := float(stump_texture.get_height())
	var fw := float(stump_texture.get_width())
	var s := minf(1.0, STUMP_MAX_HEIGHT / fh)
	_draw_shadow(stump_white, _shadow_base(cell.x, cell.y), fw * s, fh * s)


func _draw_building_shadow(cell: Vector2i, tex: Texture2D, white: Texture2D,
		max_h: float, max_w: float) -> void:
	if tex == null or white == null:
		return
	var fw := float(tex.get_width())
	var fh := float(tex.get_height())
	if fw <= 0.0 or fh <= 0.0:
		return
	var s := minf(1.0, max_h / fh)
	if max_w > 0.0:
		s = minf(s, max_w / fw)
	_draw_shadow(white, _shadow_base(cell.x, cell.y), fw * s, fh * s)


# Kun vaqtiga qarab ekran rangini qaytaradi
# 0.00 = yarim tun (qorong'i ko'k)
# 0.25 = tong (pushti-sariq)
# 0.50 = tush (yorug', oq)
# 0.75 = kech (to'q sariq)
func _day_color(t: float) -> Color:
	var night := Color(0.30, 0.35, 0.60)     # tun — qorong'i ko'k
	var dawn  := Color(0.85, 0.70, 0.65)     # tong — iliq pushti
	var noon  := Color(1.00, 1.00, 1.00)     # tush — to'liq yorug'
	var dusk  := Color(0.90, 0.65, 0.50)     # kech — to'q sariq

	if t < 0.25:
		return night.lerp(dawn, t / 0.25)
	elif t < 0.5:
		return dawn.lerp(noon, (t - 0.25) / 0.25)
	elif t < 0.75:
		return noon.lerp(dusk, (t - 0.5) / 0.25)
	else:
		return dusk.lerp(night, (t - 0.75) / 0.25)


func _visible_range() -> Array:
	var vp = get_viewport_rect().size
	var corners = [to_local(Vector2(0,0)), to_local(Vector2(vp.x,0)), to_local(Vector2(0,vp.y)), to_local(vp)]
	var min_c = 1 << 30; var max_c = -(1 << 30)
	var min_r = 1 << 30; var max_r = -(1 << 30)
	for p in corners:
		var g = local_to_grid(p)
		min_c = min(min_c, g.x); max_c = max(max_c, g.x)
		min_r = min(min_r, g.y); max_r = max(max_r, g.y)
	return [min_c-2, max_c+3, min_r-2, max_r+3]

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
		# TEZLIK: col ni s ga qarab cheklaymiz -> behuda iteratsiya yo'q
		var cA: int = maxi(c0, s - r1)
		var cB: int = mini(c1, s - r0)
		for col in range(cA, cB + 1):
			var row = s - col
			var gcell := Vector2i(col, row)
			var gr := _ground_type(col, row)
			if use_blocks and gr == "water" and block_tex.has("block_water"):
				# --- SUV BLOKI: yerdan PASTROQ (cho'kkan ko'l) ---
				_draw_block(block_tex["block_water"], col, row)
			elif use_blocks and gr != "water":
				# --- 3D BLOK (qalinlikka ega) + TERRASA BALANDLIGI ---
				var lvl := _elevation(col, row)
				var lift := float(lvl) * LEVEL_LIFT
				var bname := _block_name_for(gr, gcell)

				# Cliff yon devori: shu ustundan PAST bo'lgan old qo'shnilarga
				# qarab, ochilib qolgan yonni block_dirt bilan to'ldiramiz.
				# Old (kameraga qaragan) qo'shnilar: SE=(col+1,row), SW=(col,row+1).
				var lvl_se := _front_level(col + 1, row)
				var lvl_sw := _front_level(col, row + 1)
				var lowest: int = mini(lvl_se, lvl_sw)   # -1 = suv
				var floor_lvl: int = maxi(lowest + 1, 0)
				var dirt = block_tex.get("block_dirt", null)
				var kk := lvl - 1
				while kk >= floor_lvl:
					_draw_block(dirt, col, row, -(float(kk) * LEVEL_LIFT))
					kk -= 1

				# Ust yuzasi (biom bloki), ko'tarilgan holda
				_draw_block(block_tex.get(bname, null), col, row, -lift)
				# Ekin -> bug'doy bloki yer ustiga (o'sha balandlikda)
				if crops.has(gcell):
					var st: int = clampi(int(crops[gcell]["stage"]), 0, 3)
					_draw_block(block_tex.get("block_wheat_" + str(st), null), col, row, -lift)
			else:
				# --- Zaxira: yassi tayl (suv yoki bloklar topilmasa) ---
				var gtex: Texture2D
				if tilled_cells.has(gcell):
					gtex = _get_tex("tile_004")
				elif _tile_cache.has(gcell):
					gtex = _tile_cache[gcell]
				else:
					var gname: String
					if gr == "water":
						gname = _water_tile_for(col, row)
					else:
						gname = _stable_pick(GROUND[gr], col, row, 1)
					gtex = _get_tex(gname)
					if _tile_cache.size() > 60000:
						_tile_cache.clear()
					_tile_cache[gcell] = gtex
				if gtex != null:
					var gc := grid_to_local(col, row)
					draw_texture(gtex, gc - Vector2(float(gtex.get_width()) * 0.5,
						float(gtex.get_height()) * 0.5))
				if not use_blocks:
					_draw_cliff_cached(col, row)
			if paths.has(gcell):
				_draw_path(gcell)
			if plazas.has(gcell):
				_draw_plaza(gcell)

	# 1.5) SOYALAR — yer ustiga, obyektlardan OLDIN chiziladi.
	# (Aks holda soya boshqa daraxt ustiga tushib qolardi.)
	if Lang.shadows and _daylight() > 0.02:
		for s in range(r0 + c0, r1 + c1 + 1):
			var sA: int = maxi(c0, s - r1)
			var sB: int = mini(c1, s - r0)
			for col in range(sA, sB + 1):
				var row = s - col
				var cell := Vector2i(col, row)
				if workbenches.has(cell):
					_draw_building_shadow(cell, workbench_texture, workbench_white,
						WORKBENCH_MAX_HEIGHT, WORKBENCH_MAX_WIDTH)
				elif furnaces.has(cell):
					_draw_building_shadow(cell, furnace_texture, furnace_white,
						FURNACE_MAX_HEIGHT, FURNACE_MAX_WIDTH)
				elif windmills.has(cell):
					_draw_building_shadow(cell, windmill_texture, windmill_white,
						WINDMILL_MAX_HEIGHT, WINDMILL_MAX_WIDTH)
				elif magic_tables.has(cell):
					_draw_building_shadow(cell, magic_table_texture, magic_table_white,
						MAGIC_TABLE_MAX_HEIGHT, MAGIC_TABLE_MAX_WIDTH)
				elif anvils.has(cell):
					_draw_building_shadow(cell, anvil_texture, anvil_white,
						ANVIL_MAX_HEIGHT, ANVIL_MAX_WIDTH)
				elif chests.has(cell):
					_draw_building_shadow(cell, chest_texture, chest_white,
						CHEST_MAX_HEIGHT, CHEST_MAX_WIDTH)
				elif fences.has(cell):
					_draw_building_shadow(cell, fence_texture, fence_white,
						FENCE_MAX_HEIGHT, FENCE_MAX_WIDTH)
				elif organs.has(cell):
					_draw_building_shadow(cell, organ_texture, organ_white,
						ORGAN_MAX_HEIGHT, ORGAN_MAX_WIDTH)
				elif beacons.has(cell):
					_draw_building_shadow(cell, beacon_texture, beacon_white,
						BEACON_MAX_HEIGHT, BEACON_MAX_WIDTH)
				elif posts.has(cell):
					_draw_building_shadow(cell, post_texture, post_white,
						POST_MAX_HEIGHT, POST_MAX_WIDTH)
				elif kilns.has(cell):
					_draw_building_shadow(cell, kiln_texture, kiln_white,
						KILN_MAX_HEIGHT, KILN_MAX_WIDTH)
				else:
					var sdeco = _decor_at(col, row)
					if sdeco == "tree" or sdeco == "cactus":
						_draw_tree_shadow(col, row)
					elif sdeco == "rock":
						_draw_rock_shadow(col, row)
					elif sdeco == "stump":
						_draw_stump_shadow(cell)

	# 2) OBYEKTLAR + PERSONAJ + HAYVONLAR — chuqurlik (s = col+row) bo'yicha
	var player_drawn = false
	# Hayvonlarni ham chuqurlik bo'yicha aralashtirib chizamiz (daraxt orqasida
	# ko'rinishi uchun). Saralab, s ga qarab navbat bilan chizamiz.
	var anim_list := []
	for a in animals:
		if is_instance_valid(a):
			var ac := local_to_grid(a.position)
			anim_list.append({"a": a, "d": ac.x + ac.y})
	anim_list.sort_custom(func(x, y): return int(x["d"]) < int(y["d"]))
	var anim_i := 0
	for s in range(r0 + c0, r1 + c1 + 1):
		# Personaj shu chuqurlikda bo'lsa — obyektlardan OLDIN chizamiz
		# (shunda oldindagi (kattaroq s) obyektlar personajni to'sadi)
		if not player_drawn and s > p_depth:
			_draw_player()
			player_drawn = true
		# Shu chuqurlikdan oldingi hayvonlarni chizamiz
		while anim_i < anim_list.size() and s > int(anim_list[anim_i]["d"]):
			_draw_animal_sprite(anim_list[anim_i]["a"])
			anim_i += 1

		var oA: int = maxi(c0, s - r1)
		var oB: int = mini(c1, s - r0)
		for col in range(oA, oB + 1):
			var row = s - col
			var cell := Vector2i(col, row)
			if workbenches.has(cell):
				_draw_workbench(cell)
			elif furnaces.has(cell):
				_draw_furnace(cell)
			elif windmills.has(cell):
				_draw_windmill(cell)
			elif magic_tables.has(cell):
				_draw_magic_table(cell)
			elif anvils.has(cell):
				_draw_anvil(cell)
			elif chests.has(cell):
				_draw_chest(cell)
			elif fences.has(cell):
				_draw_fence(cell)
			elif bridges.has(cell):
				_draw_bridge(cell)
			elif organs.has(cell):
				_draw_organ(cell)
			elif cauldrons.has(cell):
				_draw_cauldron(cell)
			elif posts.has(cell):
				_draw_post(cell)
			elif kilns.has(cell):
				_draw_kiln(cell)
			elif beacons.has(cell):
				_draw_beacon(cell)
			elif crops.has(cell) and not use_blocks:
				_draw_crop(cell)
			else:
				var deco = _decor_at(col, row)
				if deco == "tree" or deco == "cactus":
					_draw_tree(col, row)
				elif deco == "rock":
					_draw_rock(col, row)
				elif deco == "stump":
					_draw_stump(cell)
				elif deco == "grasstuft":
					_draw_grasstuft(cell)
				elif deco != "":
					_draw_decor(_stable_pick(DECOR[deco], col, row, 2), col, row)

	# Agar hali chizilmagan bo'lsa (eng oldinda) — oxirida chizamiz
	if not player_drawn:
		_draw_player()

	# Qolgan (eng oldindagi) hayvonlar
	while anim_i < anim_list.size():
		_draw_animal_sprite(anim_list[anim_i]["a"])
		anim_i += 1

	# LAN: boshqa o'yinchilar
	_draw_net_players()

	# Barcha o'tinlarni chizamiz (personajdan keyin — ustida ko'rinadi)
	_draw_all_wood()

	# Urish bo'laklari — eng ustida
	_draw_chips()

	# Kristall ustun tungi nuri
	_draw_beacon_glow()

	# Qo'lda qurilma bo'lsa — QO'YISH ARVOHI ko'rsatiladi
	if _is_placeable_equipped() and not inv_open and not craft_open \
			and not workbench_open and not magic_open and not anvil_open \
			and not chest_open:
		_draw_placement_ghost()

	# Yaqindagi qurilma tepasida "R" tugmasi belgisi
	var inter := _nearby_interactable()
	if inter.size() == 2:
		var icell: Vector2i = inter[0]
		var ih: float = inter[1]
		_draw_key_badge(grid_to_local(icell.x, icell.y) - Vector2(0.0, ih + 11.0), "R")

	# Sariq romb — faqat BO'SH yerda (daraxt/toshda oq kontur ko'rsatiladi)
	var hov_deco = _decor_at(hovered_cell.x, hovered_cell.y)
	if not _is_placeable_equipped() \
			and hov_deco != "tree" and hov_deco != "cactus" and hov_deco != "rock" \
			and not workbenches.has(hovered_cell) \
			and not furnaces.has(hovered_cell) \
			and not windmills.has(hovered_cell) \
			and not magic_tables.has(hovered_cell) \
			and not chests.has(hovered_cell) \
			and not fences.has(hovered_cell) \
			and not anvils.has(hovered_cell):
		var hc = grid_to_local(hovered_cell.x, hovered_cell.y)
		draw_colored_polygon(PackedVector2Array([
			hc + Vector2(0, -TILE_H/2.0), hc + Vector2(TILE_W/2.0, 0),
			hc + Vector2(0, TILE_H/2.0), hc + Vector2(-TILE_W/2.0, 0),
		]), Color(1, 1, 0.4, 0.25))


func _process(delta: float) -> void:
	# INFO paneli faqat kraft oynasi ochiq bo'lsagina ko'rinadi
	if info_open and not (workbench_open or magic_open or anvil_open):
		info_open = false
	hovered_cell = local_to_grid(to_local(get_global_mouse_position()))

	_anim_timer += delta
	_beacon_t += delta

	# AVTOSAQLASH — har AUTOSAVE_EVERY soniyada (o'yin yopilib qolsa ham yo'qolmaydi)
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_EVERY:
		_autosave_t = 0.0
		save_game()

	# ---- LAN: o'z holatimizni yuboramiz ----
	if net_active and player != null:
		_net_send_t += delta
		if _net_send_t >= NET_SEND_RATE:
			_net_send_t = 0.0
			var spr := player as AnimatedSprite2D
			var an := ""
			var fr := 0
			if spr != null:
				an = str(spr.animation)
				fr = int(spr.frame)
			net_player_state.rpc(player.position, bool(spr.flip_h) if spr != null else false, an, fr)

	# ---- TUTORIAL kuzatuvi (kartalar o'z paytida chiqishi uchun) ----
	if tutorial_active:
		_tut_time += delta
		if player != null and not _tut_moved:
			if player.position.distance_to(_tut_spawn_pos) > 28.0:
				_tut_moved = true
		if inv_open:
			_tut_opened_inv = true
	if _anim_timer >= 1.0 / TREE_FPS:
		_anim_timer = 0.0
		var max_tree_frames := 1
		for info in _tree_data:
			max_tree_frames = max(max_tree_frames, int(info.get("frames", 1)))
		tree_anim_frame = (tree_anim_frame + 1) % max_tree_frames

	# Kamera — DEADZONE bilan. Joyida turib A/D ni tez bossang, personaj
	# markaziy qutidan chiqmaydi -> kamera QIMIRLAMAYDI -> ekran titramaydi.
	# Personaj qutidan chiqsagina kamera silliq ergashadi.
	if player != null:
		var vp = get_viewport_rect().size
		var cam_center = vp / 2.0
		var pscreen = cam_offset + player.position * zoom
		var dz = Vector2(46.0, 34.0)     # deadzone yarim-o'lchami (px)
		var target = cam_offset
		var dxp = pscreen.x - cam_center.x
		if dxp > dz.x:
			target.x = cam_offset.x - (dxp - dz.x)
		elif dxp < -dz.x:
			target.x = cam_offset.x - (dxp + dz.x)
		var dyp = pscreen.y - cam_center.y
		if dyp > dz.y:
			target.y = cam_offset.y - (dyp - dz.y)
		elif dyp < -dz.y:
			target.y = cam_offset.y - (dyp + dz.y)
		cam_offset = cam_offset.lerp(target, 10.0 * delta)
		# TITRASH TUZATISHI: kamerani BUTUN pikselga tekislaymiz.
		# Kasr qiymatda piksel-art bloklar 'raqsga tushadi'.
		position = cam_offset.round()
		last_player_safe_pos = player.position

	# ---- SAKRASH fizikasi ----
	if jump_z > 0.0 or jump_vel != 0.0:
		jump_z += jump_vel * delta
		jump_vel -= GRAVITY * delta
		if jump_z <= 0.0:
			jump_z = 0.0
			jump_vel = 0.0

	# ---- HAYVONLARNI PAYDO QILISH / OLIB TASHLASH ----
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_update_animals()

	# Jon olgandan keyingi qisqa himoyani kamaytiramiz
	if _hurt_cooldown > 0.0:
		_hurt_cooldown -= delta

	# HUD ni yangilaymiz
	if hud_node != null:
		hud_node.queue_redraw()

	# ---- YOMG'IR ----
	weather_timer += delta
	if weather_timer >= next_weather_change:
		weather_timer = 0.0
		raining = not raining
		# Yomg'ir 20-50 soniya, quruq havo 40-90 soniya
		next_weather_change = randf_range(20.0, 50.0) if raining else randf_range(40.0, 90.0)
		if raining:
			print("Yomg'ir boshlandi")
		else:
			print("Yomg'ir tindi")

	# Yomg'ir kuchi silliq o'zgaradi
	var rain_goal = 1.0 if raining else 0.0
	rain_fade = move_toward(rain_fade, rain_goal, delta * 0.4)

	# Yomg'ir ovozi: yog'ganda balandroq, tinganda pasayadi
	if rain_player != null:
		rain_player.volume_db = lerpf(-60.0, -9.0, clampf(rain_fade, 0.0, 1.0)) 			+ linear_to_db(maxf(0.0001, Lang.vol_weather))

	if rain_fade > 0.01:
		_update_rain(delta)

	# ---- EKIN O'SISHI (yomg'irda 2x tez) ----
	var _crop_rate := 2.0 if rain_fade > 0.3 else 1.0
	for ccell in crops.keys():
		var cc: Dictionary = crops[ccell]
		if int(cc["stage"]) < CROP_STAGES - 1:
			cc["grow"] = float(cc["grow"]) + delta * _crop_rate
			if float(cc["grow"]) >= CROP_GROW_TIME:
				cc["grow"] = 0.0
				cc["stage"] = int(cc["stage"]) + 1

	# ---- TUN / KUNDUZ aylanishi ----
	time_of_day += delta / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	if canvas_mod != null:
		var c = _day_color(time_of_day)
		# Yomg'irda dunyo qorong'iroq va ko'kimtir bo'ladi
		if rain_fade > 0.01:
			c = c.lerp(Color(0.55, 0.60, 0.72), rain_fade * 0.55)
		canvas_mod.color = c

	# Ogohlantirish taymeri
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_text = ""

	# Silkinish taymerini kamaytiramiz
	if shake_timer > 0:
		shake_timer -= delta

	# Oq yonish taymeri
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			flash_cell = null

	# Urish bo'laklari fizikasi
	_update_chips(delta)

	# O'tin fizikasi (sakrash, tushish, personajga uchish)
	_update_wood(delta)
	_update_kilns(delta)
	_update_toasts(delta)

	# ============================================================
	# DARAxt / TOSH CHOPISH
	# ============================================================

	if chop_target != null and player != null and not chop_in_progress:
		var target_cell: Vector2i = chop_target
		var target_kind: String = chop_kind

		# Obyekt allaqachon yo'q bo'lsa
		if _decor_at(target_cell.x, target_cell.y) == "":
			chop_target = null
			chop_kind = ""
			chop_in_progress = false
		else:
			var target_pos := grid_to_local(target_cell.x, target_cell.y)
			var dist := player.position.distance_to(target_pos)

			# Avval obyekt yoniga boradi (A* yo'li _click_world da berilgan)
			if dist > REACH:
				# Yo'l tugab, lekin hali yaqin kelmagan bo'lsa -> yana yaqinlashishga urinamiz
				if player.has_method("is_moving") and not player.is_moving():
					_chop_stuck += get_process_delta_time()
					# Qolgan qisqa masofani to'g'ri chiziq bilan bosib o'tamiz
					if player.has_method("walk_to"):
						player.walk_to(_stand_position_for_cell(target_cell))
					# Faqat CHINAKAM tiqilib qolsa (2.5s) -> bekor
					if _chop_stuck > 2.5:
						chop_target = null
						chop_kind = ""
						chop_in_progress = false
						_chop_stuck = 0.0
						show_hint(Lang.t("hint.cant_reach"))
				else:
					_chop_stuck = 0.0   # yuryapti -> taymer nol
			else:
				_chop_stuck = 0.0
				chop_in_progress = true

				# Yurishni to'xtat
				if player.has_method("stop_walking"):
					player.stop_walking()

				# Nishonga qarab tursin (animatsiya to'g'ri tomonga)
				if player.has_method("face_point"):
					player.face_point(target_pos)

				# Daraxt silkinsin
				shake_cell = target_cell
				shake_timer = 0.25

				# Obyekt bir lahza oqarib yonsin
				flash_cell = target_cell
				flash_timer = FLASH_TIME

				# Undan mayda bo'laklar sakrab chiqsin
				_spawn_hit_chips(target_cell, target_kind)

				# Ovoz
				if target_kind == "rock":
					play_sfx("hit_stone", -5.0)
				else:
					play_sfx("chop_wood", -4.0)

				# ====================================================
				# HP NI ANIMATSIYADAN OLDIN KAMAYTIRAMIZ
				# ====================================================

				var max_hp := TREE_MAX_HP
				if target_kind == "rock":
					max_hp = ROCK_MAX_HP
				elif target_kind == "stump":
					max_hp = STUMP_MAX_HP
				elif target_kind == "grasstuft":
					max_hp = GRASS_MAX_HP

				var current_hp: int = int(
					decor_hp.get(target_cell, max_hp)
				)

				current_hp -= max(1, get_tool_damage(target_kind))

				print(
					"URILDI | ",
					target_kind,
					" | HP: ",
					current_hp,
					"/",
					max_hp
				)

				# HP ni DARHOL saqlaymiz
				decor_hp[target_cell] = current_hp

				# Animatsiya
				await player.do_action("swing")

				# ====================================================
				# HP 0 = OBYEKT YO'Q
				# ====================================================

				if current_hp <= 0:
					print("SINDI: ", target_kind)

					# Bu cell endi decor hisoblanmaydi
					broken[target_cell] = true
					_dt_cache.erase(target_cell)
					if net_active:
						net_broken.rpc(target_cell)

					# HP ni tozalash
					decor_hp.erase(target_cell)

					# Drop
					if target_kind == "tree":
						_spawn_drop(target_cell, "wood", get_tool_bonus("tree"))
						play_sfx("tree_fall", -6.0)
					elif target_kind == "stump":
						# Kunda kam yog'och beradi — atigi 1 ta
						_spawn_drop(target_cell, "stump_wood", 0)
						play_sfx("tree_fall", -8.0, 0.2)
					elif target_kind == "grasstuft":
						_spawn_drop(target_cell, "grass", 0)
						play_sfx("chop_wood", -12.0, 0.25)
					else:
						_spawn_drop(target_cell, "stone", get_tool_bonus("rock"))
						play_sfx("tree_fall", -9.0, 0.15)

					# Chop tugadi
					chop_target = null
					chop_kind = ""
					shake_cell = null
					chop_in_progress = false

					# DARHOL qayta chiz
					queue_redraw()

				else:
					# Keyingi zarba
					await get_tree().create_timer(CHOP_HIT_DELAY).timeout
					chop_in_progress = false

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Sichqoncha g'ildiragi bilan zoom O'CHIRILDI (foydalanuvchi so'rovi).
		# Zoomni faqat klaviaturadagi + / - o'zgartiradi.

		# --- TUTORIAL kartasi: "Tushundim" tugmasi ---
		# --- SETTINGS menyusi bosilishi ---
		if settings_open and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var act := settings_panel.click(event.position)
			if act != "":
				_settings_action(act)
			queue_redraw()
			return   # ochiq menyu ustidagi bosish o'yinga o'tmaydi
		if settings_open:
			return

		if _tutorial_should_show() and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if tutorial_btn_rect.has_point(event.position):
				_tutorial_advance()
				return
			if tutorial_card_rect.has_point(event.position):
				return   # kartani bosish o'yin dunyosiga o'tmasin

		# INVENTAR ochiq: chap tugma bilan narsani SUDRAB ko'chiramiz
		if inv_open and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var idx := inv_slot_at(event.position)
				if idx >= 0 and inv[idx] != null:
					if bool(inv[idx].get("infinite", false)):
						# CHEKSIZ narsa (Yasash stoli): manba katakda QOLADI,
						# qo'lga esa BITTA oddiy nusxa olinadi.
						# Uni yerga qo'ysang tugaydi, inventarda esa doim bor.
						drag_item = {
							"name": inv[idx]["name"],
							"icon": inv[idx]["icon"],
							"count": 1,
						}
						drag_from = -1   # asl joyi yo'q — bu nusxa
					else:
						drag_item = inv[idx]
						drag_from = idx
						inv[idx] = null
					queue_redraw()
			else:
				# Qo'yib yuborildi
				if drag_item != null:
					var idx2 := inv_slot_at(event.position)
					if idx2 >= 0:
						drop_drag_into(idx2)
					else:
						_cancel_drag()
			return

		# SANDIQ ochiq bo'lsa: chap klik narsani ko'chiradi
		if chest_open and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var hit := chest_slot_at(event.position)
			if hit.size() == 2:
				if hit[0] == "chest":
					chest_take(int(hit[1]))
				else:
					chest_put(int(hit[1]))
			return

		# CraftingTable / Anvil / MagicTable ichida chap klik qatorni tanlaydi.
		if (workbench_open or magic_open or anvil_open) and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var recipe_idx := _craft_recipe_at_screen(event.position)
			if recipe_idx >= 0:
				if magic_open:
					magic_selected = recipe_idx
					_try_magic_craft(recipe_idx)
				elif anvil_open:
					anvil_selected = recipe_idx
					_try_anvil_craft(recipe_idx)
				else:
					craft_selected = recipe_idx
					_try_craft(recipe_idx)
			return

		if (workbench_open or magic_open or anvil_open) and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var ridx := _craft_recipe_at_screen(event.position)
			if ridx >= 0:
				var rec_list: Array = MAGIC_RECIPES if magic_open else (ANVIL_RECIPES if anvil_open else RECIPES)
				info_item = str(rec_list[ridx]["name"])
				info_open = true
				queue_redraw()
			return

		# INFO paneli ochiq bo'lsa, yopish tugmasini (x) tekshiramiz
		if info_open and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if info_close_rect.has_point(event.position):
				info_open = false
				queue_redraw()
				return

		# KILN paneli: collect tugmasi yoki retsept qatori
		if kiln_open and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if kiln_collect_rect.has_point(event.position):
				_kiln_collect()
				return
			var kidx := _kiln_recipe_at_screen(event.position)
			if kidx >= 0:
				_kiln_start(kidx)
			return

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var place_cell := local_to_grid(to_local(get_global_mouse_position()))
			_place_building(place_cell)
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_panning = true
				did_drag = false
				pan_last = event.position
				press_start = event.position
			else:
				is_panning = false
				if not did_drag:
					var hb := _hotbar_slot_at(event.position)
					if hb >= 0:
						selected_slot = hb
						queue_redraw()
					else:
						_click_world()
			return

	# Sozlamalar ochiq: chap tugma bosilgan holda surish — slayderlar ergashadi
	if settings_open and event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if settings_panel.drag(event.position) == "volumes":
				apply_volumes()
		return

	if event is InputEventMouseMotion and is_panning:
		if inv_open or craft_open or workbench_open or magic_open or anvil_open or chest_open or kiln_open:
			return
		# Sichqoncha bilan kamera SURILMAYDI (faqat zoom g'ildirak bilan).
		# Biroz sudralsa -> "drag" deb belgilaymiz, chop/qo'yish adashmasin.
		if event.position.distance_to(press_start) > 6.0:
			did_drag = true
		return

	if event is InputEventKey and event.pressed:
		# --- IP yozish rejimi (LAN sahifasi) ---
		if settings_open and typing_ip:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
				typing_ip = false
				if join_ip.strip_edges() == "":
					join_ip = "127.0.0.1"
			elif event.keycode == KEY_BACKSPACE:
				if join_ip.length() > 0:
					join_ip = join_ip.substr(0, join_ip.length() - 1)
			else:
				var ch := char(event.unicode)
				if ch.length() > 0 and (ch.is_valid_int() or ch == "."):
					if join_ip.length() < 15:
						join_ip += ch
			queue_redraw()
			return
		# ESC — sozlamalar menyusini ochadi/yopadi
		if event.keycode == KEY_ESCAPE:
			if settings_open:
				if settings_panel.escape():
					settings_open = false
				queue_redraw()
				return
			if not (inv_open or craft_open or workbench_open or magic_open or anvil_open or chest_open or kiln_open):
				settings_open = true
				settings_panel.reset()
				queue_redraw()
				return
		# Sozlamalar ochiq bo'lsa — boshqa o'yin tugmalari ishlamaydi
		if settings_open:
			return
		# E — faqat ochiq oynani yopadi.
		# Eski E -> oddiy crafting oynasini ochish logikasi olib tashlandi.
		if event.keycode == KEY_E:
			if chest_open:
				chest_open = false
			elif inv_open:
				if drag_item != null:
					_cancel_drag()
				inv_open = false
			elif workbench_open:
				workbench_open = false
			elif anvil_open:
				anvil_open = false
			elif kiln_open:
				kiln_open = false
			elif craft_open:
				craft_open = false
			elif magic_open:
				magic_open = false
			else:
				if _is_placeable_equipped():
					placement_rotation += PI / 2.0
					queue_redraw()
				else:
					# Qo'l bo'sh -> E inventarni ochadi/yopadi (ISO-CORE kabi)
					inv_open = not inv_open
					queue_redraw()
			return

		# R — SICHQONCHA USTIDAGI qurilma oynasini ochadi.
		# (Avval qat'iy tartib bor edi: chest -> anvil -> magic -> workbench,
		#  shuning uchun CraftingTable ustida tursang ham Anvil ochilardi.)
		if event.keycode == KEY_R:
			inv_open = false
			craft_open = false

			var target := _nearby_interactable()
			if target.is_empty():
				# Sichqoncha hech narsa ustida emas -> hammasini yopamiz
				workbench_open = false
				magic_open = false
				anvil_open = false
				chest_open = false
				kiln_open = false
				return

			var cell: Vector2i = target[0]

			# Avval hammasini yopamiz, keyin keraklisini ochamiz
			var was_wb := workbench_open
			var was_av := anvil_open
			var was_mt := magic_open
			var was_ch := chest_open and open_chest_cell == cell
			var was_kl := kiln_open and open_kiln_cell == cell
			workbench_open = false
			anvil_open = false
			magic_open = false
			chest_open = false
			kiln_open = false

			if workbenches.has(cell):
				workbench_open = not was_wb
			elif anvils.has(cell):
				anvil_open = not was_av
			elif magic_tables.has(cell):
				magic_open = not was_mt
			elif chests.has(cell):
				if not was_ch:
					chest_open = true
					open_chest_cell = cell
			elif kilns.has(cell):
				if not was_kl:
					kiln_open = true
					open_kiln_cell = cell
			return

		# Q — qurilmani CHAPGA / O'NGGA qaratish (oyna)
		if event.keycode == KEY_Q:
			if not inv_open and not craft_open and not workbench_open and not magic_open and not anvil_open and _is_placeable_equipped():
				placement_flip = not placement_flip
				show_hint(Lang.t("hint.facing") + ": " + (Lang.t("hint.left") if placement_flip else Lang.t("hint.right")), 1.2)
				queue_redraw()
				return

		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			if drag_item != null:
				_cancel_drag()
			craft_open = false
			workbench_open = false
			magic_open = false
			anvil_open = false
			chest_open = false
			kiln_open = false
			inv_open = not inv_open
			return

		if inv_open or craft_open or workbench_open or magic_open or anvil_open or chest_open or kiln_open:
			if event.keycode == KEY_ESCAPE:
				if drag_item != null:
					_cancel_drag()
				inv_open = false
				craft_open = false
				workbench_open = false
				magic_open = false
				anvil_open = false
				chest_open = false
				kiln_open = false
			elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
				var idx = event.keycode - KEY_1
				if magic_open:
					if idx < MAGIC_RECIPES.size():
						magic_selected = idx
						_try_magic_craft(idx)
				elif anvil_open:
					if idx < ANVIL_RECIPES.size():
						anvil_selected = idx
						_try_anvil_craft(idx)
				elif workbench_open or craft_open:
					if idx < RECIPES.size():
						craft_selected = idx
						_try_craft(idx)
			elif event.keycode == KEY_9:
				if magic_open:
					var idx := 8
					if idx < MAGIC_RECIPES.size():
						magic_selected = idx
						_try_magic_craft(idx)
				elif anvil_open:
					var idx := 8
					if idx < ANVIL_RECIPES.size():
						anvil_selected = idx
						_try_anvil_craft(idx)
				elif workbench_open or craft_open:
					var idx := 8
					if idx < RECIPES.size():
						craft_selected = idx
						_try_craft(idx)
			elif event.keycode == KEY_0:
				if magic_open:
					var idx := 9
					if idx < MAGIC_RECIPES.size():
						magic_selected = idx
						_try_magic_craft(idx)
				elif anvil_open:
					var idx := 9
					if idx < ANVIL_RECIPES.size():
						anvil_selected = idx
						_try_anvil_craft(idx)
				elif workbench_open or craft_open:
					var idx := 9
					if idx < RECIPES.size():
						craft_selected = idx
						_try_craft(idx)
			return

		if event.keycode == KEY_EQUAL:
			_zoom_at(get_viewport_rect().size / 2.0, 1.15)
		elif event.keycode == KEY_MINUS:
			_zoom_at(get_viewport_rect().size / 2.0, 1.0 / 1.15)
		elif event.keycode == KEY_SPACE:
			if jump_z <= 0.0:
				jump_vel = JUMP_POWER
				play_sfx("jump", -10.0)
		elif event.keycode == KEY_C:
			follow_player = true
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			selected_slot = event.keycode - KEY_1
# Inventar oynasining joylashuvi (chizish va bosish uchun bir manba).
func inv_layout(vp: Vector2) -> Dictionary:
	var cell := 49.0
	var gap := 3.0
	var grid_w := float(INV_COLS) * cell + float(INV_COLS - 1) * gap
	var grid_h := float(INV_ROWS) * cell + float(INV_ROWS - 1) * gap
	var x := (vp.x - grid_w) / 2.0
	var y := (vp.y - grid_h) / 2.0 + 10.0
	return {
		"cell": cell, "gap": gap,
		"x": x, "y": y,
		"grid_w": grid_w, "grid_h": grid_h,
	}


# Sichqoncha inventarning qaysi katagida? (-1 = hech qaysi)
func inv_slot_at(screen_pos: Vector2) -> int:
	var L := inv_layout(get_viewport_rect().size)
	var cell: float = L["cell"]
	var gap: float = L["gap"]
	for i in range(INV_SIZE):
		var r := i / INV_COLS
		var c := i % INV_COLS
		var rect := Rect2(L["x"] + float(c) * (cell + gap),
			L["y"] + float(r) * (cell + gap), cell, cell)
		if rect.has_point(screen_pos):
			return i
	return -1


# Ushlangan narsani katakka qo'yadi (band bo'lsa almashtiradi)
func drop_drag_into(idx: int) -> void:
	if drag_item == null:
		return
	if idx < 0 or idx >= inv.size():
		# Bo'sh joyga tashlandi -> asl joyiga qaytaramiz
		_cancel_drag()
		return
	var target = inv[idx]
	inv[idx] = drag_item
	# Nishon band edi -> uni ushlangan narsaning eski joyiga qo'yamiz
	if target != null:
		if drag_from >= 0 and drag_from < inv.size():
			inv[drag_from] = target
		else:
			# Nusxa edi (cheksiz manbadan) -> nishondagini bo'sh katakka
			add_item(target["name"], target["icon"], int(target["count"]))
	drag_item = null
	drag_from = -1
	_refresh_counts()
	play_sfx("collect", -12.0, 0.1)


func _cancel_drag() -> void:
	# drag_from = -1 bo'lsa bu cheksiz manbadan olingan nusxa -> qaytarish shart emas
	if drag_item != null and drag_from >= 0 and drag_from < inv.size():
		if inv[drag_from] == null:
			inv[drag_from] = drag_item
		else:
			add_item(drag_item["name"], drag_item["icon"], int(drag_item["count"]))
	drag_item = null
	drag_from = -1
	queue_redraw()


# Sandiq oynasining joylashuvi. Chizish ham, bosish ham shundan foydalanadi.
func chest_layout(vp: Vector2) -> Dictionary:
	var cell := 44.0
	var gap := 3.0
	var title_h := 34.0
	var grid_w := float(CHEST_COLS) * cell + float(CHEST_COLS - 1) * gap
	var chest_h := float(CHEST_ROWS) * cell + float(CHEST_ROWS - 1) * gap
	var inv_h := float(INV_ROWS) * cell + float(INV_ROWS - 1) * gap
	var mid_gap := 22.0
	var total_h := title_h + 6.0 + chest_h + mid_gap + title_h + 6.0 + inv_h
	var x := (vp.x - grid_w) / 2.0
	var y := maxf(20.0, (vp.y - total_h) / 2.0 - 20.0)
	return {
		"cell": cell, "gap": gap, "title_h": title_h,
		"x": x, "y": y, "grid_w": grid_w,
		"chest_y": y + title_h + 6.0,
		"chest_h": chest_h,
		"inv_title_y": y + title_h + 6.0 + chest_h + mid_gap,
		"inv_y": y + title_h + 6.0 + chest_h + mid_gap + title_h + 6.0,
		"inv_h": inv_h,
	}


# Sichqoncha sandiq oynasining qaysi katagida?
# Qaytaradi: ["chest", idx] / ["inv", idx] / [] (hech qaysi)
func chest_slot_at(screen_pos: Vector2) -> Array:
	var L := chest_layout(get_viewport_rect().size)
	var cell: float = L["cell"]
	var gap: float = L["gap"]

	for i in range(CHEST_SIZE):
		var r := i / CHEST_COLS
		var c := i % CHEST_COLS
		var rect := Rect2(L["x"] + c * (cell + gap), L["chest_y"] + r * (cell + gap), cell, cell)
		if rect.has_point(screen_pos):
			return ["chest", i]

	for i in range(INV_SIZE):
		var r2 := i / INV_COLS
		var c2 := i % INV_COLS
		var rect2 := Rect2(L["x"] + c2 * (cell + gap), L["inv_y"] + r2 * (cell + gap), cell, cell)
		if rect2.has_point(screen_pos):
			return ["inv", i]

	return []


# Universal kraft panelidagi bosishni topadi.
# MUHIM: bu yerdagi hisob-kitob _draw_craft_ui bilan AYNAN bir xil
# bo'lishi shart, aks holda bosish qatorlarga to'g'ri kelmaydi.
# Sichqoncha KILN panelidagi qaysi retsept qatorida turibdi (-1 = hech qaysi).
# Koordinata hisobi _draw_kiln_panel bilan AYNAN bir xil bo'lishi shart.
func _kiln_recipe_at_screen(pos: Vector2) -> int:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0
	var y := 30.0 + 46.0 + 64.0 + 22.0 + 26.0
	var panel_w := 260.0
	var row_h := 32.0
	var gap := 4.0
	var x := cx - panel_w / 2.0
	for i in range(KILN_RECIPES.size()):
		var ry := y + float(i) * (row_h + gap)
		if Rect2(x, ry, panel_w, row_h).has_point(pos):
			return i
	return -1


func _craft_recipe_at_screen(screen_pos: Vector2) -> int:
	var vp := get_viewport_rect().size
	var recipes: Array
	var cols: int
	if magic_open:
		recipes = MAGIC_RECIPES
		cols = 2
	elif anvil_open:
		recipes = ANVIL_RECIPES
		cols = 1
	else:
		recipes = RECIPES
		cols = 1

	var row_h := 34.0
	var gap := 4.0
	var col_w := 268.0
	var panel_w: float = float(cols) * col_w + float(cols - 1) * gap
	panel_w = minf(panel_w, vp.x - 40.0)
	col_w = (panel_w - float(cols - 1) * gap) / float(cols)
	var rows: int = int(ceil(float(recipes.size()) / float(cols)))
	var title_h := 34.0
	var total_h: float = title_h + 14.0 + float(rows) * (row_h + gap)
	var x := (vp.x - panel_w) / 2.0
	var y := maxf(24.0, (vp.y - total_h) / 2.0 - 30.0)
	var start_y := y + title_h + 14.0

	for i in range(recipes.size()):
		var cc: int = i % cols
		var rr: int = int(i / cols)
		var rect := Rect2(x + float(cc) * (col_w + gap),
			start_y + float(rr) * (row_h + gap), col_w, row_h)
		if rect.has_point(screen_pos):
			return i

	return -1


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before = to_local(screen_pos)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	scale = Vector2(zoom, zoom)
	cam_offset += screen_pos - to_global(before)
	position = cam_offset


func _is_building_cell(cell: Vector2i) -> bool:
	return workbenches.has(cell) or furnaces.has(cell) or windmills.has(cell) \
		or magic_tables.has(cell) or anvils.has(cell) or chests.has(cell) \
		or fences.has(cell) or organs.has(cell) or beacons.has(cell) \
		or cauldrons.has(cell) or posts.has(cell) or kilns.has(cell)

# HARAKAT uchun to'siq: faqat SUV va qurilmalar.
# Daraxt/tosh endi to'siq EMAS — o'yinchi ularning orqasiga o'tadi,
# obyekt esa shaffof bo'lib, personaj ko'rinib turadi.
func _is_blocking_cell(cell: Vector2i) -> bool:
	# Ko'prik ustidan yuriladi. Suv endi TO'SIQ EMAS — personaj suzadi.
	if bridges.has(cell):
		return false
	return _is_building_cell(cell)


# BAND katak: qurilma qo'yish / hayvon paydo bo'lishi uchun.
# Bu yerda daraxt va tosh ham hisobga olinadi.
func _is_occupied_cell(cell: Vector2i) -> bool:
	if _ground_type(cell.x, cell.y) == "water":
		return true
	var deco := _decor_at(cell.x, cell.y)
	if deco == "tree" or deco == "cactus" or deco == "rock":
		return true
	return _is_building_cell(cell)

func _stand_position_for_cell(cell: Vector2i) -> Vector2:
	var target := grid_to_local(cell.x, cell.y)
	var dirs := [
	Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8),
	Vector2(6, 6), Vector2(-6, 6), Vector2(6, -6), Vector2(-6, -6)
	]
	var best := target
	var best_dist := INF
	for d in dirs:
		var p = target + d
		if not _is_blocking_cell(local_to_grid(p)):
			var dist := player.position.distance_to(p)
			if dist < best_dist:
				best_dist = dist
				best = p
	return best


# =========================================================================
#  YO'L TOPISH (A*) — suv/bino/to'siqni AYLANIB o'tadi
# =========================================================================
# Ikki nuqta orasida to'g'ri chiziq TOZAmi (to'siq yo'qmi)?
func _has_clear_line(a: Vector2, b: Vector2) -> bool:
	var steps: int = int(a.distance_to(b) / 6.0) + 1
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pp: Vector2 = a.lerp(b, t)
		if _is_blocking_cell(local_to_grid(pp)):
			return false
	return true


func _compute_path(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var pts: Array = []
	# Maydon: to'siqni AYLANIB o'tish uchun keng margin kerak (16 katak).
	var minx: int = mini(from_cell.x, to_cell.x) - 16
	var maxx: int = maxi(from_cell.x, to_cell.x) + 16
	var miny: int = mini(from_cell.y, to_cell.y) - 16
	var maxy: int = maxi(from_cell.y, to_cell.y) + 16
	var rw: int = maxx - minx + 1
	var rh: int = maxy - miny + 1
	if rw > 130 or rh > 130:
		return pts   # juda uzoq -> A* yo'q (chaqiruvchi to'g'ri chiziqqa o'tadi)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(minx, miny, rw, rh)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for c in range(minx, maxx + 1):
		for r in range(miny, maxy + 1):
			if _is_blocking_cell(Vector2i(c, r)):
				astar.set_point_solid(Vector2i(c, r), true)
	# Boshlanish va maqsad katagini har doim ochiq qoldiramiz
	astar.set_point_solid(from_cell, false)
	astar.set_point_solid(to_cell, false)
	var cells: Array = astar.get_id_path(from_cell, to_cell)
	if cells.size() <= 1:
		return pts   # yo'l yo'q (masalan suv bilan o'ralgan)

	# Xom yo'l (player pozitsiyasidan boshlab)
	var raw: Array = [player.position]
	for i in range(1, cells.size()):
		var cc: Vector2i = cells[i]
		raw.append(grid_to_local(cc.x, cc.y))

	# STRING-PULLING: burchak-burchak (jagged) yurishni yo'qotadi.
	# Anchordan to'g'ri ko'rinadigan eng uzoq nuqtagacha sakraydi.
	var anchor: Vector2 = raw[0]
	var j: int = 1
	while j < raw.size():
		if j == raw.size() - 1:
			pts.append(raw[j])
			break
		if _has_clear_line(anchor, raw[j + 1]):
			j += 1                  # keyingisi ham ko'rinadi -> bu nuqta keraksiz
		else:
			pts.append(raw[j])
			anchor = raw[j]
			j += 1
	return pts


# Personajni katakka yuboradi (A* bilan to'siqni aylanib).
# stand=true -> obyekt YONIGA boradi. Qaytaradi: yo'l topildimi (bool).
func _walk_player_to_cell(cell: Vector2i, stand: bool = false) -> bool:
	if player == null:
		return false
	# Allaqachon shu maqsadga ketayotgan bo'lsa qayta hisoblamaymiz
	if cell == _last_path_target and player.has_method("is_moving") and player.is_moving():
		return true
	_last_path_target = cell
	var target_pos: Vector2 = _stand_position_for_cell(cell) if stand else grid_to_local(cell.x, cell.y)
	# Allaqachon yetarlicha yaqin bo'lsa -> yo'l shart emas (yonида turgan holat)
	if player.position.distance_to(target_pos) <= 16.0:
		return true
	var from_cell := local_to_grid(player.position)
	var to_cell := local_to_grid(target_pos)
	var span: int = maxi(absi(from_cell.x - to_cell.x), absi(from_cell.y - to_cell.y))
	# Bir xil katak yoki juda yaqin -> to'g'ri chiziq (A* shart emas)
	if from_cell == to_cell or span <= 2:
		if player.has_method("walk_to"):
			player.walk_to(target_pos)
		return true
	var route := _compute_path(from_cell, to_cell)
	if route.is_empty():
		if span > 100:
			# Juda uzoq -> to'g'ri chiziq (best effort)
			if player.has_method("walk_to"):
				player.walk_to(target_pos)
			return true
		return false   # o'rta masofa, lekin yo'l yo'q -> yetib bo'lmaydi
	route[route.size() - 1] = target_pos   # oxirgi nuqta aniq stand pozitsiya
	if player.has_method("follow_path"):
		player.follow_path(route)
	elif player.has_method("walk_to"):
		player.walk_to(target_pos)
	return true

func _is_placeable_equipped() -> bool:
	var e := get_equipped()
	return e == "Yasash stoli" or e == "Anvil" or e == "Furnace" \
		or e == "Windmill" or e == "MagicTable" or e == "Sandiq" \
		or e == "To'siq" or e == "Ko'prik" or e == "Yo'lak" or e == "Organ" \
		or e == "Kristall ustun" or e == "Qozon" \
		or e == "Yog'och ustun" or e == "Ko'ra" or e == "Tosh maydon"


# Chap klik: obyektni tanlaydi.
# O'yinchi yetib borgach, obyekt singuncha avtomatik uradi.
# Yangi urish uchun qayta-qayta click qilish shart emas.
const REACH := 26.0   # personaj qancha uzoqdagi narsani chopa oladi (kattaroq -> chetda qolmaydi)

# Sichqoncha hotbarning qaysi katagida? (-1 = hech qaysi). HUD bilan bir xil o'lcham.
func _hotbar_slot_at(pos: Vector2) -> int:
	var vp := get_viewport_rect().size
	var slot := 48.0
	var gap := 4.0
	var total_w := float(HOTBAR_SLOTS) * slot + float(HOTBAR_SLOTS - 1) * gap
	var start_x := (vp.x - total_w) / 2.0
	var y := vp.y - 72.0
	for i in range(HOTBAR_SLOTS):
		var r := Rect2(start_x + float(i) * (slot + gap), y, slot, slot)
		if r.has_point(pos):
			return i
	return -1


func _click_world() -> void:
	if player == null:
		return

	follow_player = true
	var cell := local_to_grid(to_local(get_global_mouse_position()))

	# ---- 1) Qurilmalarni qaytarib olish ----
	# DIQQAT: return lar IF ICHIDA bo'lishi shart, aks holda funksiya
	# birinchi tekshiruvdan keyin doim to'xtaydi.
	if workbenches.has(cell):
		_collect_building(cell, "workbench", "Yasash stoli")
		return
	if furnaces.has(cell):
		_collect_building(cell, "furnace", "Furnace")
		return
	if windmills.has(cell):
		_collect_building(cell, "windmill", "Windmill")
		return
	if magic_tables.has(cell):
		_collect_building(cell, "magic_table", "MagicTable")
		return
	if anvils.has(cell):
		_collect_building(cell, "anvil", "Anvil")
		return
	if chests.has(cell):
		# Ichida narsa bo'lsa olib bo'lmaydi (narsalar yo'qolmasin)
		if not _chest_is_empty(cell):
			show_hint(Lang.t("hint.empty_chest"))
			play_sfx("fail", -8.0, 0.0)
			return
		_collect_building(cell, "chest", "Sandiq")
		return
	if fences.has(cell):
		_collect_building(cell, "fence", "To'siq")
		return
	if bridges.has(cell):
		_collect_building(cell, "bridge", "Ko'prik")
		return
	if organs.has(cell):
		_collect_building(cell, "organ", "Organ")
		return
	if paths.has(cell):
		_collect_building(cell, "path", "Yo'lak")
		return
	if beacons.has(cell):
		_collect_building(cell, "beacon", "Kristall ustun")
		return
	if cauldrons.has(cell):
		_collect_building(cell, "cauldron", "Qozon")
		return
	if posts.has(cell):
		_collect_building(cell, "post", "Yog'och ustun")
		return
	if kilns.has(cell):
		_collect_building(cell, "kiln", "Ko'ra")
		return
	if plazas.has(cell):
		_collect_building(cell, "plaza", "Tosh maydon")
		return

	# ---- Hayvon (slime/boar/stag) — bosilgan joyda mob bo'lsa urish ----
	if _attack_nearby_animal(cell):
		return

	# ---- Ekin: pishgan bo'lsa yig'ish; urug' bo'lsa ekish ----
	if crops.has(cell):
		_harvest_crop(cell)
		return
	if get_equipped() == "Urug'" and tilled_cells.has(cell) and not crops.has(cell):
		_plant_seed(cell)
		return

	# ---- 2) Daraxt / kaktus / tosh ----
	var deco := _decor_at(cell.x, cell.y)
	if deco == "tree" or deco == "cactus" or deco == "rock" or deco == "stump" or deco == "grasstuft":
		if not can_harvest(deco):
			play_sfx("fail", -8.0, 0.0)
			show_hint(harvest_hint(deco))
			return
		chop_target = cell
		# Kaktus -> "tree" kabi ishlaydi, kunda -> alohida "stump"
		chop_kind = "tree" if deco == "cactus" else deco
		pending_chop_hits = 999999
		chop_in_progress = false
		_last_path_target = Vector2i(999999, 999999)   # yangi maqsad -> qayta yo'l
		if not _walk_player_to_cell(cell, true):
			chop_target = null
			chop_kind = ""
			show_hint(Lang.t("hint.cant_reach"))
			play_sfx("fail", -8.0, 0.0)
		return

	# ---- 3) Bo'sh yer: faqat BELKURAK qazadi -> SUV paydo bo'ladi ----
	var ground := _ground_type(cell.x, cell.y)
	if ground == "water":
		return
	if not _is_occupied_cell(cell):
		var eq := get_equipped()
		# BELKURAK -> yerni qazib SUV chiqaradi
		if eq == "Belkurak":
			if player.position.distance_to(grid_to_local(cell.x, cell.y)) > BUILDING_REACH:
				_last_path_target = Vector2i(999999, 999999)
				_walk_player_to_cell(cell, true)
				return
			dug_cells[cell] = true
			tilled_cells.erase(cell)
			if net_active:
				net_ground.rpc("dug", cell)
			for dc in [-2, -1, 0, 1, 2]:
				for dr in [-2, -1, 0, 1, 2]:
					var k := cell + Vector2i(dc, dr)
					_gt_cache.erase(k)
					_dt_cache.erase(k)
					_tile_cache.erase(k)
					_cliff_cache.erase(k)
					_elev_cache.erase(k)
			if player.has_method("face_point"):
				player.face_point(grid_to_local(cell.x, cell.y))
			if player.has_method("do_action"):
				player.do_action("dig")
			play_sfx("hit_stone", -5.0)
			queue_redraw()
			return
		# KIRKA -> yerni haydab TUPROQ (tile_004) qiladi (ekin uchun). Tosh ham sindiradi.
		if eq == "Kirka":
			if player.position.distance_to(grid_to_local(cell.x, cell.y)) > BUILDING_REACH:
				_last_path_target = Vector2i(999999, 999999)
				_walk_player_to_cell(cell, true)
				return
			tilled_cells[cell] = true
			if net_active:
				net_ground.rpc("tilled", cell)
			if player.has_method("face_point"):
				player.face_point(grid_to_local(cell.x, cell.y))
			if player.has_method("do_action"):
				player.do_action("dig")
			play_sfx("hit_stone", -6.0, 0.2)
			queue_redraw()
			return
		# Boshqa asbob -> yerni qazib bo'lmaydi
		if is_tool(eq):
			play_sfx("fail", -8.0, 0.0)
			show_hint(Lang.t("hint.ground"))
			chop_target = null
			chop_kind = ""
			return
		# Qo'l bo'sh -> o'sha katakka yuramiz (faqat "mouse" rejimida)
		chop_target = null
		chop_kind = ""
		if Lang.control_scheme == "mouse":
			_last_path_target = Vector2i(999999, 999999)
			_walk_player_to_cell(cell, false)
		return

	# ---- 4) Boshqa hollarda ----
	chop_target = null
	chop_kind = ""
	pending_chop_hits = 0


func _collect_building(cell: Vector2i, icon_name: String, item_name: String) -> void:
	if player == null:
		return

	var p := grid_to_local(cell.x, cell.y)
	var dist := player.position.distance_to(p)
	if dist > BUILDING_REACH:
		_last_path_target = Vector2i(999999, 999999)
		_walk_player_to_cell(cell, true)
		return

	var saved_rotation = building_rotations.get(cell, 0.0)
	if workbenches.has(cell):
		workbenches.erase(cell)
	elif furnaces.has(cell):
		furnaces.erase(cell)
	elif windmills.has(cell):
		windmills.erase(cell)
	elif magic_tables.has(cell):
		magic_tables.erase(cell)
	elif anvils.has(cell):
		anvils.erase(cell)
	elif chests.has(cell):
		chests.erase(cell)
	elif fences.has(cell):
		fences.erase(cell)
	elif bridges.has(cell):
		bridges.erase(cell)
	elif organs.has(cell):
		organs.erase(cell)
	elif paths.has(cell):
		paths.erase(cell)
	elif beacons.has(cell):
		beacons.erase(cell)
	elif cauldrons.has(cell):
		cauldrons.erase(cell)
	elif posts.has(cell):
		posts.erase(cell)
	elif kilns.has(cell):
		kilns.erase(cell)
	elif plazas.has(cell):
		plazas.erase(cell)
	else:
		return

	if add_item(item_name, icon_name, 1):
		building_rotations.erase(cell)
		building_flips.erase(cell)
		if net_active:
			net_remove.rpc(cell)
		play_sfx("collect", -8.0, 0.12)
	else:
		# Inventar to'la bo'lsa obyektni joyiga qaytaramiz.
		match icon_name:
			"workbench":
				workbenches[cell] = true
			"furnace":
				furnaces[cell] = true
			"windmill":
				windmills[cell] = true
			"magic_table":
				magic_tables[cell] = true
			"anvil":
				anvils[cell] = true
			"chest":
				chests[cell] = _new_chest_storage()
			"fence":
				fences[cell] = true
			"bridge":
				bridges[cell] = true
			"organ":
				organs[cell] = true
			"path":
				paths[cell] = true
			"beacon":
				beacons[cell] = true
			"cauldron":
				cauldrons[cell] = true
			"post":
				posts[cell] = true
			"kiln":
				kilns[cell] = true
			"plaza":
				plazas[cell] = true
		building_rotations[cell] = saved_rotation
		play_sfx("fail", -8.0, 0.0)

	queue_redraw()


func _find_nearby_workbench() -> Vector2i:
	if player == null:
		return Vector2i(999999, 999999)

	var best_cell := Vector2i(999999, 999999)
	var best_dist := INF

	for cell in workbenches.keys():
		var c: Vector2i = cell
		var p := grid_to_local(c.x, c.y)
		var d := player.position.distance_to(p)
		if d <= WORKBENCH_REACH and d < best_dist:
			best_dist = d
			best_cell = c

	return best_cell


func _find_nearby_anvil() -> Vector2i:
	if player == null:
		return Vector2i(999999, 999999)
	var best_cell := Vector2i(999999, 999999)
	var best_dist := INF
	for cell in anvils.keys():
		var c: Vector2i = cell
		var p := grid_to_local(c.x, c.y)
		var d := player.position.distance_to(p)
		if d <= ANVIL_REACH and d < best_dist:
			best_dist = d
			best_cell = c
	return best_cell


func _find_nearby_magic_table() -> Vector2i:
	if player == null:
		return Vector2i(999999, 999999)
	var best_cell := Vector2i(999999, 999999)
	var best_dist := INF
	for cell in magic_tables.keys():
		var c: Vector2i = cell
		var p := grid_to_local(c.x, c.y)
		var d := player.position.distance_to(p)
		if d <= MAGIC_TABLE_REACH and d < best_dist:
			best_dist = d
			best_cell = c
	return best_cell


func _can_place_building(cell: Vector2i) -> bool:
	if _ground_type(cell.x, cell.y) == "water":
		return false

	var deco := _decor_at(cell.x, cell.y)
	if deco == "tree" or deco == "cactus" or deco == "rock":
		return false

	if _is_building_cell(cell):
		return false

	return true


# Qo'lda turgan narsaga qarab QO'YISH mumkinmi?
# Ko'prik -> suvga ham, yerga ham. Yo'lak -> faqat yerga. Qolgani -> yerga.
func _placement_ok(eq: String, cell: Vector2i) -> bool:
	# Ustma-ust qo'yilmasin
	if _is_building_cell(cell) or bridges.has(cell) or paths.has(cell) \
			or plazas.has(cell):
		return false
	var deco := _decor_at(cell.x, cell.y)
	if deco == "tree" or deco == "cactus" or deco == "rock":
		return false
	var g := _ground_type(cell.x, cell.y)
	match eq:
		"Ko'prik":
			# Ko'prik suvga yoki yerga qo'yiladi
			return true
		_:
			# Boshqa hamma narsa faqat quruqlikka
			return g != "water"


func _place_building(cell: Vector2i) -> void:
	if not _placement_ok(get_equipped(), cell):
		play_sfx("fail", -8.0, 0.0)
		return

	var equipped := get_equipped()
	var object_type := ""
	var item_name := ""

	match equipped:
		"Yasash stoli":
			object_type = "workbench"
			item_name = "Yasash stoli"
		"Furnace":
			object_type = "furnace"
			item_name = "Furnace"
		"Windmill":
			object_type = "windmill"
			item_name = "Windmill"
		"MagicTable":
			object_type = "magic_table"
			item_name = "MagicTable"
		"Anvil":
			object_type = "anvil"
			item_name = "Anvil"
		"Sandiq":
			object_type = "chest"
			item_name = "Sandiq"
		"To'siq":
			object_type = "fence"
			item_name = "To'siq"
		"Ko'prik":
			object_type = "bridge"
			item_name = "Ko'prik"
		"Yo'lak":
			object_type = "path"
			item_name = "Yo'lak"
		"Organ":
			object_type = "organ"
			item_name = "Organ"
		"Kristall ustun":
			object_type = "beacon"
			item_name = "Kristall ustun"
		"Qozon":
			object_type = "cauldron"
			item_name = "Qozon"
		"Yog'och ustun":
			object_type = "post"
			item_name = "Yog'och ustun"
		"Ko'ra":
			object_type = "kiln"
			item_name = "Ko'ra"
		"Tosh maydon":
			object_type = "plaza"
			item_name = "Tosh maydon"
		_:
			return

	if not consume_equipped(1):
		play_sfx("fail", -8.0, 0.0)
		return

	match object_type:
		"workbench":
			workbenches[cell] = true
		"furnace":
			furnaces[cell] = true
		"windmill":
			windmills[cell] = true
		"magic_table":
			magic_tables[cell] = true
		"anvil":
			anvils[cell] = true
		"chest":
			chests[cell] = _new_chest_storage()
		"fence":
			fences[cell] = true
		"bridge":
			bridges[cell] = true
		"path":
			paths[cell] = true
		"organ":
			organs[cell] = true
		"beacon":
			beacons[cell] = true
		"cauldron":
			cauldrons[cell] = true
		"post":
			posts[cell] = true
		"kiln":
			kilns[cell] = true
		"plaza":
			plazas[cell] = true

	building_rotations[cell] = fmod(placement_rotation, TAU)
	building_flips[cell] = placement_flip
	if net_active:
		net_place.rpc(object_type, cell, building_rotations[cell], placement_flip)
	play_sfx("collect", -8.0, 0.05)
	queue_redraw()


# Eski nom bilan qolgan chaqiruvlar uchun wrapper.
func _place_workbench(cell: Vector2i) -> void:
	_place_building(cell)


	# O'tinlarni har kadr yangilaydi: sakrash -> tushish -> personajga uchish
func _update_wood(delta: float) -> void:
	if wood_items.is_empty():
		return
	var now = Time.get_ticks_msec()
	var gravity := 140.0
	var survivors := []
	for item in wood_items:
		var age = now - item["born"]

		if item["state"] == WOOD_FLY:
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
				item["state"] = WOOD_SETTLE

		elif item["state"] == WOOD_SETTLE:
			# Yerda sochilib YOTADI. Personaj yaqin kelsagina uchadi.
			if player != null and age > 350:
				if player.position.distance_to(item["pos"]) < 46.0:
					item["state"] = WOOD_TO_PLAYER

		elif item["state"] == WOOD_TO_PLAYER:
			# Personajga uchib boradi (tezlashib)
			if player == null:
				continue
			var to_p = player.position - item["pos"]
			var dist = to_p.length()
			if dist < 14.0:
				# Yetdi — yig'iladi
				# Har tur ALOHIDA to'planadi (bitta "daraxt" bo'lib qo'shilmaydi)
				var item_kind: String = item.get("kind", "wood")
				if not DROP_ITEMS.has(item_kind):
					item_kind = "wood"
				var d_name: String = str(DROP_ITEMS[item_kind][0])
				var d_icon: String = str(DROP_ITEMS[item_kind][1])
				add_item(d_name, d_icon, 1)
				_toast(d_name, d_icon, 1)
				if item_kind == "stone":
					stone_count = count_item("Tosh")
				elif item_kind == "wood":
					wood_count = count_item("Yog'och")
				play_sfx("collect", -8.0, 0.12)
				continue
			var step: float = minf(dist, 300.0 * delta)   # oshib ketmaydi -> aylanmaydi
			item["pos"] += to_p.normalized() * step

		survivors.append(item)

	wood_items = survivors



	# =========================================================================
	#  HUD — jon (yuraklar), quvvat (yashil chiziq), hotbar (8 katak)
	#  Ekran ustida chiziladi, kamera bilan harakatlanmaydi.
	# =========================================================================
class HudDraw extends Control:
	var world = null

	const SLOT = 48.0
	const GAP = 4.0
	const HEART = 13.0
	const ROW_H = 40.0
	const PANEL_W = 300.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if world == null:
			return
		var vp = get_viewport_rect().size
		var total_w = world.HOTBAR_SLOTS * SLOT + (world.HOTBAR_SLOTS - 1) * GAP
		var start_x = (vp.x - total_w) / 2.0
		var bottom_y = vp.y - 72.0

		_draw_rain()
		_draw_beacon_glow_hud()
		_draw_hint(vp)
		# JON — ekran TEPASIDA, o'rtada, qora shaffof pilla ichida
		_draw_health_pill(vp)
		_draw_fps(vp)
		_draw_net_badge(vp)
		_draw_toasts(vp)
		_draw_equipped(start_x + total_w / 2.0, bottom_y - 22.0)
		_draw_hotbar(start_x, bottom_y, total_w)
		# Chap-pastdagi doimiy resurs paneli olib tashlandi:
		# yig'ilgan narsa endi faqat o'ng-yuqoridagi vaqtinchalik toast bilan
		# ko'rsatiladi (bir necha soniyada o'chadi). Umumiy son hotbar'da ko'rinadi.

		# Inventar ochiq bo'lsa — fon qorayadi
		if world.inv_open or world.craft_open or world.workbench_open \
				or world.magic_open or world.chest_open:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45))
			# Panellar fon ustida qayta chiziladi
			_draw_hotbar(start_x, bottom_y, total_w)

		if world.inv_open:
			_draw_inventory(vp)

		# Universal kraft paneli (ISO-CORE devlog dizayni)
		if world.workbench_open:
			_draw_craft_ui(vp, "CRAFTING TABLE", world.RECIPES, world.craft_selected, 1)
		elif world.anvil_open:
			_draw_craft_ui(vp, "ANVIL", world.ANVIL_RECIPES, world.anvil_selected, 1)
		elif world.magic_open:
			_draw_craft_ui(vp, "MAGIC TABLE", world.MAGIC_RECIPES, world.magic_selected, 2)
		if world.chest_open:
			_draw_chest_panel(vp)
		if world.kiln_open:
			_draw_kiln_panel(vp)

		# ---- TUTORIAL kartasi (eng ustida) ----
		_draw_tutorial(vp)
		_draw_settings(vp)

	# ---- TUTORIAL (o'rgatuvchi karta) ----
	func _draw_tutorial(vp: Vector2) -> void:
		if not world._tutorial_should_show():
			return
		var t = world.tutorials[world.tutorial_index]
		var font: Font = ThemeDB.fallback_font
		var x := 16.0
		var y := 16.0
		var w := 340.0
		var pad := 14.0
		var title_size := 16
		var body_size := 13
		var body_w := w - pad * 2.0
		var tkey := str(t["key"])
		var title := Lang.t(tkey + ".t")
		var body := Lang.t(tkey + ".b")
		var body_h: float = font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, body_w, body_size).y
		var btn_h := 27.0
		var total_h := pad + float(title_size) + 10.0 + body_h + 12.0 + btn_h + pad
		var card := Rect2(x, y, w, total_h)

		# Fon paneli
		_draw_rounded_panel(card, Color(0.05, 0.09, 0.06, 0.93),
			Color(0.30, 0.42, 0.28, 0.85), 9.0, 1.0)

		# Sarlavha
		draw_string(font, Vector2(x + pad, y + pad + float(title_size) - 2.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.96, 0.98, 0.90))

		# Matn (avtomatik qatorlarga bo'linadi)
		draw_multiline_string(font,
			Vector2(x + pad, y + pad + float(title_size) + 14.0), body,
			HORIZONTAL_ALIGNMENT_LEFT, body_w, body_size, -1,
			Color(0.80, 0.88, 0.80))

		# "Tushundim" tugmasi
		var btn_w := 96.0
		var btn := Rect2(x + pad, y + total_h - pad - btn_h, btn_w, btn_h)
		_draw_rounded_panel(btn, Color(0.12, 0.22, 0.13, 0.96),
			Color(0.55, 0.72, 0.45, 0.95), 6.0, 1.0)
		var label := Lang.t("ui.got_it")
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(btn.position.x + (btn_w - lw) / 2.0,
			btn.position.y + 18.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.96, 0.98, 0.90))

		# Hisoblagich (1/7)
		var cnt := "%d/%d" % [world.tutorial_index + 1, world.tutorials.size()]
		var cw := font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(x + w - pad - cw, y + total_h - pad - 8.0), cnt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.72, 0.60))

		# Bosish sohalarini world'ga uzatamiz
		world.tutorial_btn_rect = btn
		world.tutorial_card_rect = card

	# ---- SOZLAMALAR menyusi ----
	# Bosh menyu bilan BIR XIL panel (settings_panel.gd). Til, video, ovoz,
	# boshqaruv — hammasi Lang (autoload) da saqlanadi.
	func _draw_settings(vp: Vector2) -> void:
		if not world.settings_open or world.settings_panel == null:
			return
		world.settings_panel.draw_panel(self, vp, get_global_mouse_position(), world)

	func _diamond_hud(c: Vector2, sz: float) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -sz), c + Vector2(sz, 0),
			c + Vector2(0, sz), c + Vector2(-sz, 0)]),
			Color(0.55, 0.80, 1.0))

	func _draw_beacon_glow_hud() -> void:
		if world.beacon_texture == null or world.beacons.is_empty():
			return
		var night: float = 1.0 - world._daylight()
		var strength: float = 0.25 + 0.75 * night   # kunduzi ham biroz ko'rinadi
		var pulse: float = 0.85 + 0.15 * sin(world._beacon_t * 2.2)
		var z: float = world.zoom
		var warm := Color(1.0, 0.82, 0.48)
		if world._glow_tex == null:
			return
		for bcell in world.beacons.keys():
			# -18 — yangi rasmda kristall markazi katak markazidan shuncha yuqorida
			var wl: Vector2 = world.grid_to_local(bcell.x, bcell.y) + Vector2(0.0, -18.0)
			var sp: Vector2 = world.cam_offset + wl * z
			var n: float = strength * pulse
			# Yumshoq gradient halo (halqalarsiz, tabiiy)
			var rad: float = 128.0 * pulse * z * 0.5
			draw_texture_rect(world._glow_tex,
				Rect2(sp - Vector2(rad, rad), Vector2(rad * 2.0, rad * 2.0)),
				false, Color(warm.r, warm.g, warm.b, 0.50 * n))

	# O'ng-yuqori burchakda FPS (past bo'lsa qizil, baland bo'lsa yashil)
	# LAN holati (FPS ostida)
	# ---- TOAST — yig'ilgan narsalar (o'ng chetda, stacklanadi) ----
	func _draw_toasts(vp: Vector2) -> void:
		if world.toasts.is_empty():
			return
		var font: Font = ThemeDB.fallback_font
		var y := 66.0
		for t in world.toasts:
			var timer: float = float(t["timer"])
			# Kirish/chiqish fade (oxirgi 0.5s da so'nadi)
			var fade_out: float = clampf(timer / 0.5, 0.0, 1.0)
			# Narsa nomi o'yin tiliga mos ko'rsatiladi (Lang.n)
			var txt := Lang.n(str(t["name"])) + "  +" + str(t["count"])
			var fs := 13
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var w: float = tw + 46.0
			var h := 28.0
			var x := vp.x - w - 14.0
			_draw_rounded_panel(Rect2(x, y, w, h),
				Color(0.08, 0.09, 0.07, 0.85 * fade_out), Color(0.30, 0.34, 0.22, 0.75 * fade_out), 8.0, 1.0)
			_icon(str(t["icon"]), Rect2(x + 4.0, y + 3.0, 22.0, 22.0), 2.0)
			draw_string(font, Vector2(x + 30.0, y + 19.0), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, fade_out))
			y += h + 6.0

	func _draw_net_badge(vp: Vector2) -> void:
		if not world.net_active:
			return
		var font: Font = ThemeDB.fallback_font
		var txt := ("HOST" if world.net_is_host else "CLIENT") + "  " + str(world.net_peers.size() + 1) + "P"
		var fs := 12
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := vp.x - tw - 12.0
		var y := 38.0
		draw_string(font, Vector2(x + 1.0, y + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.55, 0.85, 1.0))

	func _draw_fps(vp: Vector2) -> void:
		var fps: int = int(round(Engine.get_frames_per_second()))
		var font: Font = ThemeDB.fallback_font
		var txt := "FPS " + str(fps)
		var col := Color(0.55, 0.9, 0.55)
		if fps < 30:
			col = Color(0.95, 0.35, 0.30)
		elif fps < 50:
			col = Color(0.95, 0.82, 0.35)
		var fs := 13
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := vp.x - tw - 12.0
		var y := 20.0
		draw_string(font, Vector2(x + 1.0, y + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.65))
		draw_string(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

		# ---- YOMG'IR ----
	func _draw_rain() -> void:
		if world.rain_fade <= 0.01:
			return
		var a = world.rain_fade * 0.45
		var col = Color(0.72, 0.80, 0.95, a)
		for d in world.rain_drops:
			var p = d["pos"]
			draw_line(p, p + Vector2(-4.0, d["len"]), col, 1.0)

		# ---- SLOT RAMKASI (UI qutisi bilan) ----
	func _box(rect: Rect2, box_name: String) -> void:
		if world._ui_box.has(box_name):
			draw_texture_rect(world._ui_box[box_name], rect, false)
		else:
			draw_rect(rect, Color(0.10, 0.11, 0.13, 0.9))

		# ---- IKONKA chizish (katak ichida markazlab) ----
	func _icon(icon_name: String, rect: Rect2, pad: float) -> void:
		var tex: Texture2D = null
		if icon_name == "workbench" and world.workbench_texture != null:
			tex = world.workbench_texture
		elif icon_name == "furnace" and world.furnace_texture != null:
			tex = world.furnace_texture
		elif icon_name == "windmill" and world.windmill_texture != null:
			tex = world.windmill_texture
		elif icon_name == "magic_table" and world.magic_table_texture != null:
			tex = world.magic_table_texture
		elif icon_name == "anvil" and world.anvil_texture != null:
			tex = world.anvil_texture
		elif world._icons.has(icon_name):
			tex = world._icons[icon_name]
		if tex == null:
			return
		var s = min(rect.size.x, rect.size.y) - pad
		var pos = rect.position + (rect.size - Vector2(s, s)) / 2.0
		draw_texture_rect(tex, Rect2(pos, Vector2(s, s)), false)

		# ---- RESURS "CHIP"lari (chapda, hotbar ustida) ----
		# ISO-CORE uslubi: qora shaffof yumaloq pilla + ikonka + NOM va soni.
		# Faqat mavjud (soni > 0) resurslar ko'rinadi.
	func _draw_resource_chips(vp: Vector2, bottom_y: float) -> void:
		var font: Font = ThemeDB.fallback_font
		var wanted := ["Yog'och", "Tosh", "Mis", "Oltin", "Safir", "Bug'doy"]
		var icons := {
			"Yog'och": "log", "Tosh": "silver_ore", "Mis": "copper_ore",
			"Oltin": "gold_ore", "Safir": "sapphire", "Bug'doy": "apple",
		}
		var rows := []
		for nm in wanted:
			var c: int = int(world.count_item(nm))
			if c > 0:
				rows.append([str(icons.get(nm, "log")), Lang.n(nm).to_upper(), c])
		if rows.is_empty():
			return

		var fs := 11
		var h := 21.0
		var gap := 4.0
		var x := 16.0
		var y: float = bottom_y - 18.0 - float(rows.size()) * (h + gap)
		for r in rows:
			var txt: String = str(r[1]) + "  " + str(r[2])
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var w: float = 8.0 + 16.0 + 6.0 + tw + 9.0
			var rect := Rect2(x, y, w, h)
			_draw_rounded_panel(rect, Color(0.04, 0.05, 0.04, 0.70),
				Color(0.10, 0.13, 0.10, 0.60), 6.0, 1.0)
			_icon(str(r[0]), Rect2(x + 5.0, y + 2.5, 16.0, 16.0), 0.0)
			draw_string(font, Vector2(x + 28.0, y + 15.0), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(x + 27.0, y + 14.0), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.96, 0.92))
			y += h + gap

		# Kichkina ogohlantirish — CHAP YUQORI burchak,
	# shaffof qora fon, oq yozuv.
	func _draw_hint(vp: Vector2) -> void:
		if world.hint_timer <= 0.0 or world.hint_text == "":
			return
		var font = ThemeDB.fallback_font
		var txt = str(world.hint_text)
		var fs = 12
		var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a = clampf(world.hint_timer / 0.5, 0.0, 1.0)
		draw_rect(Rect2(14.0, 14.0, w + 14.0, 22.0), Color(0, 0, 0, 0.55 * a))
		draw_string(font, Vector2(21.0, 29.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))

	# ---- TANLANGAN ASBOB ----
	func _draw_equipped(cx: float, y: float) -> void:
		var eq = world.get_equipped()
		if eq == "":
			return
		var font = ThemeDB.fallback_font
		var txt = Lang.n(eq)
		# Asbob nimaga yaxshi ekanini yozamiz
		if world.TOOLS.has(eq):
			var g = world.TOOLS[eq]["good_for"]
			if g == "tree":
				txt += "  —  " + Lang.t("ui.for_tree")
			elif g == "rock":
				txt += "  —  " + Lang.t("ui.for_rock")
		var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - w / 2.0 + 1, y + 1), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(cx - w / 2.0, y), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.90, 0.65))

	# ---- JON — tepada, qora shaffof pilla + yurak + son ----
	func _draw_health_pill(vp: Vector2) -> void:
		var font: Font = ThemeDB.fallback_font
		var hp: int = int(world.health)
		var txt := str(hp)
		var num_w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x

		var pad := 13.0
		var heart_w := 15.0
		var w: float = pad + heart_w + 9.0 + num_w + pad
		var h := 27.0
		var x: float = (vp.x - w) / 2.0
		var y := 16.0

		# Qora shaffof pilla
		_draw_rounded_panel(Rect2(x, y, w, h),
			Color(0.04, 0.05, 0.04, 0.68), Color(0.10, 0.13, 0.10, 0.55),
			13.0, 1.0)

		# Yurak
		_heart(Vector2(x + pad + heart_w / 2.0, y + h / 2.0 - 1.0), 7.0,
			Color(0.90, 0.16, 0.24))

		# Son — oq, qora soya bilan
		var nx: float = x + pad + heart_w + 9.0
		var ny: float = y + h / 2.0 + 6.0
		draw_string(font, Vector2(nx + 1.0, ny + 1.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(nx, ny), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))

		# ---- JON (eski, ishlatilmaydi) ----
	func _draw_health(x: float, y: float) -> void:
		for i in range(world.MAX_HEALTH):
			var hx = x + i * (HEART + 3.0)
			var full = i < world.health
			var col = Color(0.90, 0.16, 0.24) if full else Color(0.22, 0.10, 0.12)
			_heart(Vector2(hx + HEART / 2.0, y), HEART / 2.0, col)

	func _heart(c: Vector2, r: float, col: Color) -> void:
		draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.55, col)
		draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.55, col)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.95, -r * 0.05),
			c + Vector2(r * 0.95, -r * 0.05),
			c + Vector2(0.0, r * 1.05),
		]), col)

		# ---- QUVVAT ----
	func _draw_stamina(x: float, y: float) -> void:
		var w = 240.0
		var h = 12.0
		draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), Color(0.06, 0.07, 0.09, 0.9))
		draw_rect(Rect2(x, y, w, h), Color(0.16, 0.18, 0.16))
		var f = clampf(world.stamina / world.MAX_STAMINA, 0.0, 1.0)
		draw_rect(Rect2(x, y, w * f, h), Color(0.45, 0.85, 0.30))
		var seg = w / 12.0
		for i in range(1, 12):
			draw_line(Vector2(x + seg * i, y), Vector2(x + seg * i, y + h),
				Color(0.08, 0.12, 0.08, 0.7), 1.0)

		# ---- HOTBAR ----
	# ---- HOTBAR — qora shaffof, yumaloq burchakli kataklar ----
	func _draw_hotbar(x: float, y: float, total_w: float) -> void:
		var items = world.get_hotbar_items()
		var font: Font = ThemeDB.fallback_font
		for i in range(int(world.HOTBAR_SLOTS)):
			var sx: float = x + float(i) * (SLOT + GAP)
			var rect := Rect2(sx, y, SLOT, SLOT)
			var sel: bool = (i == int(world.selected_slot))

			# Qora shaffof katak
			var fill := Color(0.04, 0.05, 0.04, 0.70)
			var border := Color(0.10, 0.13, 0.10, 0.60)
			if sel:
				fill = Color(0.06, 0.08, 0.06, 0.80)
				border = Color(1, 1, 1, 0.95)
			_draw_rounded_panel(rect, fill, border, 8.0, 2.0 if sel else 1.0)

			if i < items.size() and items[i] != null:
				var it = items[i]
				_icon(str(it["icon"]), rect, 14.0)
				var n: int = int(it["count"])
				if n > 0:
					_draw_stack_number(str(n),
						Vector2(rect.end.x - 6.0, rect.end.y - 6.0), font)

		# ---- INVENTAR OYNASI — REFERENCE DESIGN ----
		# Reference rasmdagi layout:
			#   [Workbench]  [ 8 x 4 inventory grid ]
		#   sarlavha grid markazida
		#   item tooltip / katta chap panel YO'Q
	func _draw_inventory(vp: Vector2) -> void:
		var font: Font = ThemeDB.fallback_font
		var L: Dictionary = world.inv_layout(vp)
		var cell: float = L["cell"]
		var gap: float = L["gap"]
		var gx: float = L["x"]
		var gy: float = L["y"]
		var grid_w: float = L["grid_w"]
		var cols: int = int(world.INV_COLS)

		# Sarlavha
		var title_w := 200.0
		var title_h := 47.0
		var title_rect := Rect2(gx + (grid_w - title_w) / 2.0, gy - 52.0,
			title_w, title_h)
		_draw_rounded_panel(title_rect, Color(0.015, 0.055, 0.045, 0.96),
			Color(0.25, 0.38, 0.29, 0.95), 7.0, 2.0)
		var title := Lang.t("ui.inventory")
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(title_rect.position.x + (title_w - tw) / 2.0,
			title_rect.position.y + 29.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.90, 0.95, 0.91))

		var mp := get_global_mouse_position()
		var hover := -1

		for i in range(int(world.INV_SIZE)):
			var r: int = i / cols
			var c: int = i % cols
			var rect := Rect2(gx + float(c) * (cell + gap),
				gy + float(r) * (cell + gap), cell, cell)
			if rect.has_point(mp):
				hover = i

			# Birinchi qator = HOTBAR. Uni ajratib ko'rsatamiz.
			var is_hotbar: bool = i < int(world.HOTBAR_SLOTS)
			var fill := Color(0.05, 0.06, 0.05, 0.80)
			var border := Color(0.12, 0.16, 0.12, 0.65)
			if is_hotbar:
				border = Color(0.42, 0.52, 0.40, 0.80)
			if hover == i:
				fill = fill.lightened(0.16)
				border = Color(0.92, 0.94, 0.85, 0.95)
			_draw_rounded_panel(rect, fill, border, 6.0, 1.0)

			var slot = world.inv[i]
			if slot != null:
				_icon(str(slot["icon"]), rect, 9.0)
				if bool(slot.get("infinite", false)):
					# Cheksiz narsa — son o'rniga ∞
					_draw_stack_number("~",
						Vector2(rect.end.x - 5.0, rect.end.y - 6.0), font)
				else:
					var n: int = int(slot["count"])
					if n > 0:
						_draw_stack_number(str(n),
							Vector2(rect.end.x - 5.0, rect.end.y - 6.0), font)

		world.inv_hover = hover

		# Pastda ko'rsatma
		var hint := Lang.t("ui.drag_hint")
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(gx + (grid_w - hw) / 2.0,
			gy + float(L["grid_h"]) + 26.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.82, 0.78))

		# Ushlangan narsa — sichqoncha ortidan yuradi
		if world.drag_item != null:
			var drect := Rect2(mp - Vector2(cell / 2.0, cell / 2.0),
				Vector2(cell, cell))
			_draw_rounded_panel(drect, Color(0.06, 0.08, 0.06, 0.85),
				Color(1, 1, 1, 0.85), 6.0, 1.0)
			_icon(str(world.drag_item["icon"]), drect, 9.0)

		# Yumaloq, shaffof panel/slot — reference UI uchun.
	func _draw_rounded_panel(rect: Rect2, fill: Color, border: Color, radius: float, border_width: float) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(int(border_width))
		box.corner_radius_top_left = int(radius)
		box.corner_radius_top_right = int(radius)
		box.corner_radius_bottom_left = int(radius)
		box.corner_radius_bottom_right = int(radius)
		draw_style_box(box, rect)

	func _draw_stack_number(txt: String, pos: Vector2, font: Font) -> void:
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		# qora shadow
		draw_string(font, Vector2(pos.x - tw + 1.0, pos.y + 1.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.90))
		# oq raqam
		draw_string(font, Vector2(pos.x - tw, pos.y), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.98))

		# Reference dizaynda hover tooltip yo'q.
	func _draw_item_info(slot, vp: Vector2) -> void:
		return

		# ---- WORKBENCH OYNASI ----
		# ---- WORKBENCH OYNASI ----
	# =================================================================
	#  UNIVERSAL KRAFT PANELI (ISO-CORE devlog dizayni)
	#    - yuqorida sarlavha
	#    - retsept qatorlari: chapda mahsulot, o'ngda materiallar
	#    - tanlangan qator yashil kontur bilan
	#    - chapda INFO paneli (nomi, tavsifi, ingredientlari)
	# =================================================================
	func _draw_craft_ui(vp: Vector2, title: String, recipes: Array,
			selected: int, cols: int) -> void:
		var font: Font = ThemeDB.fallback_font
		var mp := get_global_mouse_position()

		var row_h := 34.0
		var gap := 4.0
		var col_w := 268.0
		var panel_w: float = float(cols) * col_w + float(cols - 1) * gap
		panel_w = minf(panel_w, vp.x - 40.0)
		col_w = (panel_w - float(cols - 1) * gap) / float(cols)
		var rows: int = int(ceil(float(recipes.size()) / float(cols)))
		var title_h := 34.0
		var total_h: float = title_h + 14.0 + float(rows) * (row_h + gap)
		var x := (vp.x - panel_w) / 2.0
		var y := maxf(24.0, (vp.y - total_h) / 2.0 - 30.0)

		# --- Sarlavha (qora yumaloq panel) ---
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var tpw: float = maxf(150.0, tw + 44.0)
		_draw_rounded_panel(Rect2(x + (panel_w - tpw) / 2.0, y, tpw, title_h),
			Color(0.05, 0.05, 0.06, 0.94), Color(0.22, 0.24, 0.22, 0.95), 8.0, 1.0)
		draw_string(font, Vector2(x + (panel_w - tw) / 2.0, y + 22.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.94, 0.95, 0.90))

		# --- Retsept qatorlari ---
		var start_y := y + title_h + 14.0
		world.craft_hover = -1
		for i in range(recipes.size()):
			var r: Dictionary = recipes[i]
			var cc: int = i % cols
			var rr: int = int(i / cols)
			var rx: float = x + float(cc) * (col_w + gap)
			var ry: float = start_y + float(rr) * (row_h + gap)
			var rect := Rect2(rx, ry, col_w, row_h)
			var hov: bool = rect.has_point(mp)
			if hov:
				world.craft_hover = i

			# Resurs yetarlimi?
			var need_w := int(r.get("wood", 0))
			var need_s := int(r.get("stone", 0))
			var need_c := int(r.get("copper", 0))
			var need_g := int(r.get("gold", 0))
			var ok: bool = world.count_item("Yog'och") >= need_w \
				and world.count_item("Tosh") >= need_s \
				and world.count_item("Mis") >= need_c \
				and world.count_item("Oltin") >= need_g

			# Qator foni
			var fill := Color(0.055, 0.05, 0.045, 0.95)
			var border := Color(0.16, 0.15, 0.12, 0.95)
			if i == selected:
				border = Color(0.62, 0.92, 0.50, 0.95)
				fill = Color(0.075, 0.09, 0.055, 0.96)
			elif hov:
				border = Color(0.55, 0.60, 0.50, 0.90)
				fill = fill.lightened(0.06)
			_draw_rounded_panel(rect, fill, border, 6.0, 1.0)

			# Pastdagi progress chizig'i (resurs yetarliligi)
			var bar_col := Color(0.45, 0.85, 0.35, 0.75) if ok else Color(0.85, 0.28, 0.22, 0.75)
			draw_rect(Rect2(rx + 5.0, ry + row_h - 4.0, col_w - 10.0, 2.0), bar_col)

			# Mahsulot ikonkasi
			_icon(str(r["icon"]), Rect2(rx + 4.0, ry + 3.0, 28.0, 28.0), 3.0)

			# Nomi — FAQAT sichqoncha ustiga borganda yoki tanlangan bo'lsa ko'rinadi
			if hov or i == selected:
				var nm := str(r["name"])
				draw_string(font, Vector2(rx + 38.0, ry + 21.0), nm,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.95, 0.96, 0.92) if ok else Color(0.55, 0.55, 0.58))

			# O'ngda kerakli materiallar (ikonka + son)
			var mx := rx + col_w - 6.0
			var mats := [[need_c, "copper_ore", "Mis"], [need_g, "gold_ore", "Oltin"],
				[need_s, "silver_ore", "Tosh"], [need_w, "log", "Yog'och"]]
			for m in mats:
				var cnt := int(m[0])
				if cnt <= 0:
					continue
				var txt := str(cnt)
				var txw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				var have: bool = world.count_item(str(m[2])) >= cnt
				mx -= txw
				draw_string(font, Vector2(mx, ry + 22.0), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.95, 0.96, 0.92) if have else Color(0.95, 0.32, 0.28))
				mx -= 18.0
				_icon(str(m[1]), Rect2(mx, ry + 8.0, 16.0, 16.0), 1.0)
				mx -= 5.0

		# --- Chapdagi INFO paneli ---
		if world.info_open and world.info_item != "":
			_draw_info_panel(vp, world.info_item)

		# --- Pastda ko'rsatma ---
		var hint := "Bosib yasa  •  O'ng tugma: ma'lumot  •  E/ESC: yopish"
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(x + (panel_w - hw) / 2.0, start_y + float(rows) * (row_h + gap) + 16.0),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.68, 0.60))

	# =================================================================
	#  KILN paneli (video dizayni): chiqish slot + collect + retseptlar
	# =================================================================
	func _draw_kiln_panel(vp: Vector2) -> void:
		if not world.kiln_open:
			return
		var font: Font = ThemeDB.fallback_font
		var mp := get_global_mouse_position()
		var recipes: Array = world.KILN_RECIPES
		var job = world.kiln_jobs.get(world.open_kiln_cell, null)

		var panel_w := 260.0
		var cx := vp.x / 2.0
		var y := 30.0

		# --- Sarlavha ---
		var title := "KILN"
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var tpw: float = maxf(150.0, tw + 44.0)
		_draw_rounded_panel(Rect2(cx - tpw / 2.0, y, tpw, 34.0),
			Color(0.05, 0.05, 0.06, 0.94), Color(0.22, 0.24, 0.22, 0.95), 8.0, 1.0)
		draw_string(font, Vector2(cx - tw / 2.0, y + 22.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.94, 0.95, 0.90))
		y += 46.0

		# --- Chiqish sloti ---
		var slot_size := 64.0
		var slot := Rect2(cx - slot_size / 2.0, y, slot_size, slot_size)
		_draw_rounded_panel(slot, Color(0.05, 0.06, 0.05, 0.92), Color(0.24, 0.26, 0.22, 0.9), 8.0, 1.0)
		var ready: int = int(job.get("ready", 0)) if job != null else 0
		var ridx: int = int(job.get("recipe", -1)) if job != null else -1
		if job != null and ridx >= 0 and ridx < recipes.size():
			var r: Dictionary = recipes[ridx]
			_icon(str(r["icon"]), slot.grow(-8.0), 2.0)
			# Progress (agar hali pishayotgan bo'lsa)
			var dur: float = float(job.get("duration", 5.0))
			var el: float = float(job.get("elapsed", 0.0))
			if ready < world.KILN_MAX_READY and el > 0.01:
				var prog: float = clampf(el / dur, 0.0, 1.0)
				draw_rect(Rect2(slot.position.x + 4.0, slot.position.y + slot_size - 8.0,
					(slot_size - 8.0) * prog, 4.0), Color(0.55, 0.85, 0.40, 0.9))
			# Son (ready/MAX)
			var cnt_txt := str(ready) + "/" + str(world.KILN_MAX_READY)
			var ctw := font.get_string_size(cnt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, Vector2(cx - ctw / 2.0, slot.position.y + slot_size + 16.0),
				cnt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.94, 0.90))
			# X (bekor qilish belgisi — faqat vizual, hozircha bosilmaydi)
			draw_string(font, Vector2(slot.position.x + slot_size - 10.0, slot.position.y - 2.0), "x",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.35, 0.30))
		y += slot_size + 22.0

		# --- Collect tugmasi ---
		var cbtn_w := 74.0
		var cbtn := Rect2(cx - cbtn_w / 2.0, y - 12.0, cbtn_w, 22.0)
		var chov: bool = cbtn.has_point(mp)
		var can_collect: bool = ready > 0
		_draw_rounded_panel(cbtn,
			Color(0.10, 0.16, 0.10, 0.9) if can_collect else Color(0.07, 0.07, 0.07, 0.7),
			Color(0.55, 0.75, 0.45, 0.9) if (chov and can_collect) else Color(0.22, 0.24, 0.20, 0.8), 6.0, 1.0)
		var cl := "collect"
		var clw := font.get_string_size(cl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(cx - clw / 2.0, y + 3.0), cl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.92, 0.95, 0.90) if can_collect else Color(0.5, 0.52, 0.48))
		world.kiln_collect_rect = cbtn
		y += 26.0

		# --- Retsept qatorlari (bitta ustun, workbench uslubida) ---
		var row_h := 32.0
		var gap := 4.0
		var x := cx - panel_w / 2.0
		for i in range(recipes.size()):
			var r2: Dictionary = recipes[i]
			var ry := y + float(i) * (row_h + gap)
			var rect := Rect2(x, ry, panel_w, row_h)
			var hov: bool = rect.has_point(mp)

			var nw := int(r2.get("wood", 0))
			var ns := int(r2.get("stone", 0))
			var ng := int(r2.get("gold", 0))
			var ok: bool = world.count_item("Yog'och") >= nw and world.count_item("Tosh") >= ns \
				and world.count_item("Oltin") >= ng

			var fill := Color(0.055, 0.05, 0.045, 0.95)
			var border := Color(0.16, 0.15, 0.12, 0.95)
			if i == world.kiln_selected:
				border = Color(0.85, 0.55, 0.30, 0.95)
				fill = Color(0.10, 0.07, 0.04, 0.96)
			elif hov:
				border = Color(0.55, 0.50, 0.40, 0.9)
				fill = fill.lightened(0.06)
			_draw_rounded_panel(rect, fill, border, 6.0, 1.0)

			_icon(str(r2["icon"]), Rect2(x + 4.0, ry + 2.0, 28.0, 28.0), 3.0)
			if hov or i == world.kiln_selected:
				draw_string(font, Vector2(x + 38.0, ry + 20.0), str(r2["name"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.95, 0.96, 0.92) if ok else Color(0.55, 0.55, 0.58))

			var mx := x + panel_w - 6.0
			for m in [[ng, "gold_ore", "Oltin"], [ns, "silver_ore", "Tosh"], [nw, "log", "Yog'och"]]:
				var cnt := int(m[0])
				if cnt <= 0:
					continue
				var txt := str(cnt)
				var txw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				var have: bool = world.count_item(str(m[2])) >= cnt
				mx -= txw
				draw_string(font, Vector2(mx, ry + 21.0), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(0.95, 0.96, 0.92) if have else Color(0.95, 0.32, 0.28))
				mx -= 18.0
				_icon(str(m[1]), Rect2(mx, ry + 7.0, 16.0, 16.0), 1.0)
				mx -= 5.0

	# Chapdagi INFO paneli: nomi, tavsifi, ingredientlari
	func _draw_info_panel(vp: Vector2, item_name: String) -> void:
		var font: Font = ThemeDB.fallback_font
		var w := 226.0
		var x := 26.0
		var y := vp.y * 0.24
		var desc := str(world.ITEM_INFO.get(item_name, ""))
		var body_w := w - 28.0
		var dh: float = font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, body_w, 11).y
		var h: float = 150.0 + dh

		_draw_rounded_panel(Rect2(x, y, w, h),
			Color(0.045, 0.05, 0.045, 0.95), Color(0.24, 0.26, 0.22, 0.95), 9.0, 1.0)

		# Ikonka + nomi
		var icn: String = world._icon_for_item(item_name)
		if icn != "":
			_icon(icn, Rect2(x + 12.0, y + 12.0, 30.0, 30.0), 3.0)
		var nm := item_name
		draw_string(font, Vector2(x + 50.0, y + 33.0), nm,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.96, 0.92))

		# Info sarlavhasi + matn
		draw_string(font, Vector2(x + 12.0, y + 66.0), "Info:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.80, 0.72))
		draw_multiline_string(font, Vector2(x + 12.0, y + 84.0), desc,
			HORIZONTAL_ALIGNMENT_LEFT, body_w, 11, -1, Color(0.80, 0.84, 0.78))

		# Ingredientlar
		var iy: float = y + 92.0 + dh
		draw_string(font, Vector2(x + 12.0, iy), "Ingredients:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.80, 0.72))
		var rec: Dictionary = world._recipe_for_item(item_name)
		var ix := x + 12.0
		if rec.size() > 0:
			for m in [[int(rec.get("wood", 0)), "log"], [int(rec.get("stone", 0)), "silver_ore"],
					[int(rec.get("copper", 0)), "copper_ore"]]:
				if int(m[0]) <= 0:
					continue
				_icon(str(m[1]), Rect2(ix, iy + 10.0, 24.0, 24.0), 2.0)
				_draw_stack_number(str(int(m[0])),
					Vector2(ix + 24.0, iy + 34.0), font)
				ix += 32.0
		else:
			draw_string(font, Vector2(x + 12.0, iy + 24.0), "—",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.64, 0.58))

		# Yopish tugmasi (x)
		var cb := Rect2(x + w - 22.0, y + 6.0, 16.0, 16.0)
		var chov: bool = cb.has_point(get_global_mouse_position())
		draw_string(font, Vector2(cb.position.x + 4.0, cb.position.y + 13.0), "x",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.95, 0.45, 0.40) if chov else Color(0.7, 0.5, 0.48))
		world.info_close_rect = cb

	func _draw_workbench_panel(vp: Vector2) -> void:
		# ================================================================
		# CRAFTINGTABLE — 2-rasmdagi ixcham reference dizayn.
		#
		# Muhim:
			# - panel ataylab TOR;
		# - title "CRAFTINGTABLE" bitta so'z;
		# - 7 ta qator;
		# - chapda mahsulot icon;
		# - o'ngda material icon + soni;
		# - tanlangan qator oq kontur bilan ajraladi.
		# ================================================================
		var font: Font = ThemeDB.fallback_font
		var recipes: Array = world.RECIPES

		var panel_w := minf(220.0, vp.x - 24.0)
		var title_h := 44.0
		var row_h := 31.0
		var row_gap := 3.0
		var title_gap := 7.0
		var total_h := title_h + title_gap + recipes.size() * row_h + (recipes.size() - 1) * row_gap

		var x := (vp.x - panel_w) / 2.0
		var y := maxf(16.0, (vp.y - total_h) / 2.0)

		# Asosiy panel fonini chizamiz
		var panel_rect := Rect2(x, y, panel_w, total_h)
		_draw_rounded_panel(panel_rect, Color(0.02, 0.04, 0.03, 0.94), Color(0.15, 0.25, 0.18, 0.9), 8.0, 2.0)

		# Sarlavha qismi
		var title_rect := Rect2(x + 8.0, y + 8.0, panel_w - 16.0, title_h - 8.0)
		_draw_rounded_panel(title_rect, Color(0.015, 0.055, 0.045, 0.96), Color(0.25, 0.38, 0.29, 0.95), 6.0, 1.0)
		
		var title := Lang.t("ui.crafting")
		var title_size := 14
		var title_w_text := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		draw_string(font,
			Vector2(title_rect.position.x + (title_rect.size.x - title_w_text) / 2.0,
				title_rect.position.y + 22.0),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.90, 0.95, 0.91))

		# Retseptlar qatorini chizamiz
		var start_y = y + title_h + title_gap
		for i in range(recipes.size()):
			var r = recipes[i]
			var row_rect := Rect2(x + 8.0, start_y + i * (row_h + row_gap), panel_w - 16.0, row_h)
			var is_selected = (i == world.craft_selected)

			var bg_col := Color(0.08, 0.12, 0.10, 0.85) if not is_selected else Color(0.18, 0.28, 0.20, 0.95)
			var border_col := Color(0.15, 0.22, 0.18, 0.8) if not is_selected else Color(0.85, 0.90, 0.75, 0.95)
			
			_draw_rounded_panel(row_rect, bg_col, border_col, 5.0, 1.0)

			# Iconka va nomni chiqarish
			var icon_rect := Rect2(row_rect.position.x + 4.0, row_rect.position.y + 4.0, row_h - 8.0, row_h - 8.0)
			_icon(r["icon"], icon_rect, 4.0)

			var name_pos := Vector2(row_rect.position.x + 32.0, row_rect.position.y + 20.0)
			draw_string(font, name_pos, Lang.n(str(r["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))

			# Kerakli resurslar matni (O'ng burchakda)
			var cost_txt = "W:%d S:%d" % [r["wood"], r["stone"]]
			var cost_w = font.get_string_size(cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(row_rect.end.x - cost_w - 8.0, row_rect.position.y + 20.0),
				cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.8, 0.7))

		# Pastki hintni olib tashladik — reference'da yo'q.

		# Sichqoncha bilan qator tanlash/craft qilish:
			# input HUD ichidan ushlanmasa ham, world keyingi frame'da shu
		# koordinatani oladi. Shu sabab alohida helper ishlatamiz.
		world.craft_hover = -1
		var mp := get_global_mouse_position()
		for i in range(recipes.size()):
			var rr := Rect2(
				x,
				y + title_h + title_gap + i * (row_h + row_gap),
				panel_w,
				row_h
			)
			if rr.has_point(mp):
				world.craft_hover = i

	# ---- SANDIQ OYNASI: yuqorida CHEST, pastda INVENTORY ----
	func _draw_chest_panel(vp: Vector2) -> void:
		var store = world.get_open_chest()
		if store == null:
			return
		var font: Font = ThemeDB.fallback_font
		var L: Dictionary = world.chest_layout(vp)
		var cell: float = L["cell"]
		var gap: float = L["gap"]
		var x: float = L["x"]
		var grid_w: float = L["grid_w"]
		var mp := get_global_mouse_position()

		# --- Sarlavha: CHEST ---
		var title_h: float = L["title_h"]
		var top_y: float = L["y"]
		_panel_title(font, Lang.t("ui.chest"), x, top_y, grid_w, title_h)

		# --- Sandiq kataklari ---
		var ccols: int = int(world.CHEST_COLS)
		var chest_y: float = L["chest_y"]
		for i in range(int(world.CHEST_SIZE)):
			var r: int = i / ccols
			var c: int = i % ccols
			var rect := Rect2(x + float(c) * (cell + gap),
				chest_y + float(r) * (cell + gap), cell, cell)
			var hov: bool = rect.has_point(mp)
			_slot(rect, store[i], hov, font,
				Color(0.20, 0.15, 0.08, 0.86), Color(0.34, 0.25, 0.13, 0.75))

		# --- Sarlavha: INVENTORY ---
		var inv_title_y: float = L["inv_title_y"]
		_panel_title(font, Lang.t("ui.inventory"), x, inv_title_y, grid_w, title_h)

		# --- O'yinchi inventari ---
		var icols: int = int(world.INV_COLS)
		var inv_y: float = L["inv_y"]
		for i in range(int(world.INV_SIZE)):
			var r2: int = i / icols
			var c2: int = i % icols
			var rect2 := Rect2(x + float(c2) * (cell + gap),
				inv_y + float(r2) * (cell + gap), cell, cell)
			var hov2: bool = rect2.has_point(mp)
			_slot(rect2, world.inv[i], hov2, font,
				Color(0.015, 0.22, 0.25, 0.86), Color(0.02, 0.32, 0.34, 0.75))

		# --- Pastda qisqacha ko'rsatma ---
		var hint := Lang.t("ui.chest_hint")
		var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var inv_h: float = L["inv_h"]
		draw_string(font, Vector2(x + (grid_w - hw) / 2.0, inv_y + inv_h + 22.0),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.82, 0.78))

	# Sarlavha paneli
	func _panel_title(font: Font, txt: String, x: float, y: float,
			w: float, h: float) -> void:
		_draw_rounded_panel(Rect2(x, y, w, h),
			Color(0.015, 0.055, 0.045, 0.96), Color(0.25, 0.38, 0.29, 0.95), 7.0, 2.0)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(x + (w - tw) / 2.0, y + h - 11.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.90, 0.95, 0.91))

	# Bitta katak (narsa bilan yoki bo'sh)
	func _slot(rect: Rect2, item, hovered: bool, font: Font,
			fill: Color, border: Color) -> void:
		if hovered:
			fill = fill.lightened(0.16)
			border = Color(0.92, 0.94, 0.85, 0.95)
		_draw_rounded_panel(rect, fill, border, 6.0, 1.0)
		if item != null:
			_icon(str(item["icon"]), rect, 9.0)
			var n := int(item["count"])
			if n > 0:
				_draw_stack_number(str(n),
					Vector2(rect.end.x - 5.0, rect.end.y - 6.0), font)

	func _draw_anvil_panel(vp: Vector2) -> void:
		var font: Font = ThemeDB.fallback_font
		var recipes: Array = world.ANVIL_RECIPES
		var panel_w := minf(260.0, vp.x - 24.0)
		var title_h := 44.0
		var row_h := 34.0
		var gap := 4.0
		var total_h := title_h + 7.0 + recipes.size() * row_h + (recipes.size() - 1) * gap
		var x := (vp.x - panel_w) / 2.0
		var y := maxf(10.0, (vp.y - total_h) / 2.0)
		_draw_rounded_panel(Rect2(x,y,panel_w,title_h),Color(0.07,0.055,0.045,0.98),Color(0.22,0.18,0.13,1.0),7.0,1.0)
		var title := Lang.t("ui.anvil")
		var tw := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(font,Vector2(x+(panel_w-tw)/2.0,y+29.0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.95,0.96,0.90))
		for i in range(recipes.size()):
			var r: Dictionary = recipes[i]
			var ry := y + title_h + 7.0 + i * (row_h + gap)
			var rect := Rect2(x,ry,panel_w,row_h)
			var ok = world.count_item("Yog'och") >= int(r.get("wood",0)) and world.count_item("Tosh") >= int(r.get("stone",0))
			var border := Color(0.94,0.94,0.90,1.0) if i == world.anvil_selected else Color(0.16,0.17,0.08,0.95)
			_draw_rounded_panel(rect,Color(0.075,0.075,0.055,0.97),border,5.0,1.0)
			_icon(str(r["icon"]),Rect2(x+4.0,ry+3.0,29.0,29.0),2.0)
			draw_string(font,Vector2(x+38.0,ry+21.0),Lang.n(str(r["name"])),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE if ok else Color(0.55,0.55,0.58))
			var mx := x + panel_w - 5.0
			var sn := int(r.get("stone",0))
			if sn > 0:
				var s := str(sn); var sw := font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
				mx -= sw; draw_string(font,Vector2(mx,ry+22.5),s,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE if world.count_item("Tosh") >= sn else Color(0.95,0.30,0.30)); mx -= 19.0; _icon("silver_ore",Rect2(mx,ry+7,17,17),1.0); mx -= 5.0
			var wn := int(r.get("wood",0))
			if wn > 0:
				var w := str(wn); var ww := font.get_string_size(w,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
				mx -= ww; draw_string(font,Vector2(mx,ry+22.5),w,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE if world.count_item("Yog'och") >= wn else Color(0.95,0.30,0.30)); mx -= 19.0; _icon("log",Rect2(mx,ry+7,17,17),1.0)

	func _draw_magic_panel(vp: Vector2) -> void:
		var font: Font = ThemeDB.fallback_font
		var recipes: Array = world.MAGIC_RECIPES
		var row_h := 34.0
		var gap := 4.0
		var title_h := 44.0
		var panel_w := minf(470.0, vp.x - 24.0)
		var col_w := (panel_w - gap) / 2.0
		var rows := int(ceil(float(recipes.size()) / 2.0))
		var total_h = title_h + 7.0 + rows * row_h + max(0, rows - 1) * gap
		var x := (vp.x - panel_w) / 2.0
		var y := maxf(10.0, (vp.y - total_h) / 2.0)
		_draw_rounded_panel(Rect2(x,y,panel_w,title_h),Color(0.035,0.045,0.025,0.98),Color(0.10,0.12,0.07,1.0),7.0,1.0)
		var title := Lang.t("ui.magic")
		var tw := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(font,Vector2(x+(panel_w-tw)/2.0,y+29.0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.95,0.96,0.90))
		for i in range(recipes.size()):
			var r: Dictionary = recipes[i]
			var col := i % 2
			var rr := int(i / 2)
			var rx := x + col * (col_w + gap)
			var ry := y + title_h + 7.0 + rr * (row_h + gap)
			var rect := Rect2(rx,ry,col_w,row_h)
			var ok = world.count_item("Yog'och") >= int(r.get("wood",0)) and world.count_item("Tosh") >= int(r.get("stone",0)) and world.count_item("Mis") >= int(r.get("copper",0))
			var border := Color(0.94,0.94,0.90,1.0) if i == world.magic_selected else Color(0.16,0.17,0.08,0.95)
			_draw_rounded_panel(rect,Color(0.075,0.075,0.035,0.97),border,5.0,1.0)
			_icon(str(r["icon"]),Rect2(rx+4.0,ry+3.0,28.0,28.0),2.0)
			var mx := rx + col_w - 5.0
			var cn := int(r.get("copper",0))
			if cn > 0:
				var a := str(cn); var aw := font.get_string_size(a,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
				mx -= aw; draw_string(font,Vector2(mx,ry+22.5),a,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE if world.count_item("Mis") >= cn else Color(0.95,0.30,0.30)); mx -= 19.0; _icon("copper_ore",Rect2(mx,ry+8,17,17),1.0); mx -= 5.0
			var sn := int(r.get("stone",0))
			if sn > 0:
				var b := str(sn); var bw := font.get_string_size(b,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
				mx -= bw; draw_string(font,Vector2(mx,ry+22.5),b,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE if world.count_item("Tosh") >= sn else Color(0.95,0.30,0.30)); mx -= 19.0; _icon("silver_ore",Rect2(mx,ry+8,17,17),1.0); mx -= 5.0
			var wn := int(r.get("wood",0))
			if wn > 0:
				var c := str(wn); var cw := font.get_string_size(c,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
				mx -= cw; draw_string(font,Vector2(mx,ry+22.5),c,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE if world.count_item("Yog'och") >= wn else Color(0.95,0.30,0.30)); mx -= 19.0; _icon("log",Rect2(mx,ry+8,17,17),1.0)
	func _draw_resource_line(pos: Vector2, icon_name: String, label: String, count: int) -> void:
		_icon(icon_name, Rect2(pos, Vector2(24.0, 24.0)), 2.0)
		var col = Color(0.92, 0.96, 0.92) if count > 0 else Color(0.95, 0.35, 0.35)
		draw_string(ThemeDB.fallback_font, pos + Vector2(30.0, 18.0), label + ": " + str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

		# ---- CRAFT OYNASI (ISO-CORE uslubi) ----
	func _draw_craft_panel(vp: Vector2) -> void:
		var font = ThemeDB.fallback_font
		var recipes = world.RECIPES
		var x = (vp.x - PANEL_W) / 2.0
		var y = 70.0

		# Sarlavha
		var title_h = 38.0
		draw_rect(Rect2(x, y, PANEL_W, title_h), Color(0.07, 0.09, 0.07, 0.95))
		draw_rect(Rect2(x, y, PANEL_W, title_h), Color(0.35, 0.55, 0.35, 0.9), false, 2.0)
		draw_string(font, Vector2(x + 16, y + 25), Lang.t("ui.craft_old"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.95, 0.85))

		# Retsept qatorlari
		for i in range(recipes.size()):
			var r = recipes[i]
			var ry = y + title_h + 6.0 + i * (ROW_H + 4.0)
			var row = Rect2(x, ry, PANEL_W, ROW_H)

			var ok = world.wood_count >= r["wood"] and world.stone_count >= r["stone"]

			# Qator foni
			var bg = Color(0.10, 0.16, 0.10, 0.92) if ok else Color(0.10, 0.10, 0.11, 0.92)
			draw_rect(row, bg)
			draw_rect(row, Color(0.30, 0.45, 0.30, 0.75) if ok
				else Color(0.25, 0.25, 0.28, 0.7), false, 1.0)

			# Raqam (1,2,3...)
			draw_string(font, Vector2(x + 8, ry + 25), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.8, 0.7))

			# Yasaladigan narsa ikonkasi
			_icon(r["icon"], Rect2(x + 22, ry + 4, 32, 32), 4.0)

			# Nomi + ta'siri
			var label = Lang.n(str(r["name"]))
			if world.TOOLS.has(r["name"]):
				var g = world.TOOLS[r["name"]]["good_for"]
				if g == "tree":
					label += "  " + Lang.t("ui.tree_x2")
				elif g == "rock":
					label += "  " + Lang.t("ui.rock_x2")
			draw_string(font, Vector2(x + 60, ry + 25), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(1, 1, 1) if ok else Color(0.55, 0.55, 0.58))

			# Kerakli resurslar — o'ng tomonda
			var ix = x + PANEL_W - 16.0
			if r["stone"] > 0:
				ix -= 46.0
				_icon("silver_ore", Rect2(ix, ry + 8, 22, 22), 2.0)
				var have_s = world.stone_count >= r["stone"]
				draw_string(font, Vector2(ix + 24, ry + 25), str(r["stone"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(1, 1, 1) if have_s else Color(0.95, 0.35, 0.35))
			if r["wood"] > 0:
				ix -= 46.0
				_icon("log", Rect2(ix, ry + 8, 22, 22), 2.0)
				var have_w = world.wood_count >= r["wood"]
				draw_string(font, Vector2(ix + 24, ry + 25), str(r["wood"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(1, 1, 1) if have_w else Color(0.95, 0.35, 0.35))


		# HUD uchun: hotbar = inventarning birinchi 8 katagi
func get_hotbar_items() -> Array:
	var items := []

	for i in range(HOTBAR_SLOTS):
		if i < inv.size() and inv[i] != null:
			items.append({
				"icon": inv[i]["icon"],
				"count": int(inv[i]["count"])
			})
		else:
			items.append(null)

	return items
