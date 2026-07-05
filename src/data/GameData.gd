class_name GameData
extends RefCounted
## 游戏配置数据。
## 所有数值从 res://config/game_config.json 加载；元素相关枚举为本模块常量。
## 通过静态变量缓存，整局只解析一次。其他脚本通过 GameData.XXX 读取。

# ---- 敌人元素（固定枚举，不走 JSON）----
enum Element { PHYSICAL, FIRE, FROST, LIGHTNING }

const ELEMENT_COLOR := {
	Element.PHYSICAL: Color("e8edf5"),
	Element.FIRE: Color("ff7a3c"),
	Element.FROST: Color("6cc7ff"),
	Element.LIGHTNING: Color("ffe34a"),
}

const ELEMENT_NAME := {
	Element.PHYSICAL: "物理",
	Element.FIRE: "火焰",
	Element.FROST: "冰冻",
	Element.LIGHTNING: "雷电",
}

const CONFIG_PATH := "res://config/game_config.json"

# 缓存：首次访问时从 JSON 加载
static var _cfg: Dictionary = {}


# ============================================================
#  加载入口
# ============================================================
static func _ensure_loaded() -> void:
	if not _cfg.is_empty():
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("[GameData] 无法打开配置文件: %s" % CONFIG_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[GameData] 配置 JSON 解析失败: %s (行 %d)" % [json.get_error_message(), json.get_error_line()])
		return
	_cfg = json.data if json.data is Dictionary else {}


static func section(key: String) -> Dictionary:
	_ensure_loaded()
	return _cfg.get(key, {})


static func raw() -> Dictionary:
	_ensure_loaded()
	return _cfg


# ============================================================
#  Player
# ============================================================
static var PLAYER_BASE_MOVE_SPEED: float:
	get:
		return section("player").get("base_move_speed", 230.0)

static var PLAYER_BASE_MAX_HP: float:
	get:
		return section("player").get("base_max_hp", 100.0)

static var PLAYER_HIT_INVUL_TIME: float:
	get:
		return section("player").get("hit_invul_time", 0.7)

static var PLAYER_PICKUP_RANGE: float:
	get:
		return section("player").get("pickup_range", 70.0)


# ============================================================
#  Sword
# ============================================================
static var SWORD_BASE_COUNT: int:
	get:
		return int(section("sword").get("base_count", 1))

static var SWORD_BASE_RADIUS: float:
	get:
		return section("sword").get("base_radius", 56.0)

static var SWORD_BASE_ROT_SPEED: float:
	get:
		return section("sword").get("base_rot_speed", 2.8)

static var SWORD_BASE_SIZE: float:
	get:
		return section("sword").get("base_size", 1.0)

static var SWORD_BASE_DAMAGE: float:
	get:
		return section("sword").get("base_damage", 16.0)

static var SWORD_BASE_PIERCE: int:
	get:
		return int(section("sword").get("base_pierce", 0))

static var SWORD_HIT_COOLDOWN: float:
	get:
		return section("sword").get("hit_cooldown", 0.4)

static var SWORD_LENGTH: float:
	get:
		return section("sword").get("length", 30.0)

static var SWORD_WIDTH: float:
	get:
		return section("sword").get("width", 11.0)

static var SWORD_HIT_CAPSULE_RADIUS: float:
	get:
		return section("sword").get("hit_capsule_radius", 11.0)

static var SWORD_HIT_CAPSULE_HEIGHT: float:
	get:
		return section("sword").get("hit_capsule_height", 44.0)

static var SWORD_BASE_KNOCKBACK: float:
	get:
		return section("sword").get("base_knockback", 90.0)


# ============================================================
#  Enemy
# ============================================================
static var ENEMY_HP_SCALE_PER_SECOND: float:
	get:
		return section("enemy").get("hp_scale_per_second", 0.012)

static var ENEMY_CONTACT_INTERVAL: float:
	get:
		return section("enemy").get("contact_interval", 0.6)

static var ENEMY_MAX_COUNT: int:
	get:
		return int(section("enemy").get("max_count", 100))

static var ENEMY_CULL_CHECK_INTERVAL: float:
	get:
		return section("enemy").get("cull_check_interval", 1.0)

static var ENEMY_CULL_RADIUS: float:
	get:
		return section("enemy").get("cull_radius", 900.0)


# ============================================================
#  Spawn
# ============================================================
static var SPAWN_INTERVAL_START: float:
	get:
		return section("spawn").get("interval_start", 1.4)

static var SPAWN_INTERVAL_MIN: float:
	get:
		return section("spawn").get("interval_min", 0.32)

static var SPAWN_INTERVAL_DECAY: float:
	get:
		return section("spawn").get("interval_decay", 0.985)

static var SPAWN_RADIUS: float:
	get:
		return section("spawn").get("radius", 540.0)

static var SPAWN_WAVE_COUNT_BASE: int:
	get:
		return int(section("spawn").get("wave_count_base", 1))

static var SPAWN_WAVE_COUNT_TIME_DIVISOR: float:
	get:
		return section("spawn").get("wave_count_time_divisor", 25.0)

static var SPAWN_WAVE_COUNT_MAX: int:
	get:
		return int(section("spawn").get("wave_count_max", 5))


# ============================================================
#  XP
# ============================================================
static var ENEMY_KILL_XP_BASE: int:
	get:
		return int(section("xp").get("kill_xp_base", 1))

static var XP_GEM_VALUE_BIG: int:
	get:
		return int(section("xp").get("gem_value_big", 5))

static var XP_GEM_RADIUS: float:
	get:
		return section("xp").get("gem_radius", 6.0)

static var XP_FIRST_LEVEL: int:
	get:
		return int(section("xp").get("first_level", 5))

static var XP_GROWTH_STEP: float:
	get:
		return float(section("xp").get("growth_step", 3))

static var XP_GROWTH_QUAD: float:
	get:
		return float(section("xp").get("growth_quad", 0.15))

## 平滑升级曲线：
##   xp(lv) = first_level + growth_step*(lv-1) + growth_quad*(lv-1)^2
## 前期线性小步长（频繁升级），后期增速平缓（避免一波经验连升多级过度打断）。
static func xp_to_reach(level: int) -> int:
	var d := float(level - 1)
	return int(round(XP_FIRST_LEVEL + XP_GROWTH_STEP * d + XP_GROWTH_QUAD * d * d))


# ============================================================
#  Boss
# ============================================================
static var BOSS_SPAWN_TIME: float:
	get:
		return section("boss").get("spawn_time", 180.0)

static var BOSS_MAX_HP: float:
	get:
		return section("boss").get("max_hp", 4200.0)

static var BOSS_MOVE_SPEED: float:
	get:
		return section("boss").get("move_speed", 110.0)

static var BOSS_CONTACT_DAMAGE: float:
	get:
		return section("boss").get("contact_damage", 24.0)

static var BOSS_BODY_RADIUS: float:
	get:
		return section("boss").get("body_radius", 36.0)


# ============================================================
#  Upgrade
# ============================================================
static var UPGRADE_CHOICE_COUNT: int:
	get:
		return int(section("upgrade").get("choice_count", 3))


# ============================================================
#  Stages（多关卡）
# ============================================================
static var STAGES: Array:
	get:
		_ensure_loaded()
		var s: Variant = _cfg.get("stages", [])
		return s if s is Array else []

static var STAGE_COUNT: int:
	get:
		return STAGES.size()


# ============================================================
#  Monster Grades（5 档怪物等级）
# ============================================================
static var MONSTER_GRADES: Array:
	get:
		_ensure_loaded()
		var mg: Variant = _cfg.get("monster_grades", {})
		if mg is Dictionary:
			return mg.get("grades", [])
		return []

static var MONSTER_GRADE_COUNT: int:
	get:
		return MONSTER_GRADES.size()


## 按 id 获取某档等级定义。
static func monster_grade(gid: int) -> Dictionary:
	for g in MONSTER_GRADES:
		if int(g.get("id", -1)) == gid:
			return g
	return {}


# ============================================================
#  Bestiary Bosses（图鉴中的 Boss 数据，每关一个）
# ============================================================
static var BESTIARY_BOSSES: Array:
	get:
		_ensure_loaded()
		var bb: Variant = _cfg.get("bestiary_bosses", [])
		return bb if bb is Array else []


# ============================================================
#  Pickup Buff（可拾取道具）
# ============================================================
static var PICKUP_SPAWN_INTERVAL: float:
	get:
		return section("pickup_buff").get("spawn_interval", 9.0)

static var PICKUP_SPAWN_JITTER: float:
	get:
		return section("pickup_buff").get("spawn_interval_jitter", 4.0)

static var PICKUP_SPAWN_RADIUS_MIN: float:
	get:
		return section("pickup_buff").get("spawn_radius_min", 120.0)

static var PICKUP_SPAWN_RADIUS_MAX: float:
	get:
		return section("pickup_buff").get("spawn_radius_max", 360.0)

static var PICKUP_COLLECT_RADIUS: float:
	get:
		return section("pickup_buff").get("collect_radius", 26.0)

static var PICKUP_TYPES: Array:
	get:
		return section("pickup_buff").get("types", [])

static var PICKUP_EFFECT: Dictionary:
	get:
		return section("pickup_buff").get("effect", {})


# ============================================================
#  计算辅助
# ============================================================
static func element_name(e: int) -> String:
	return ELEMENT_NAME.get(e, "物理")


static func element_color(e: int) -> Color:
	return ELEMENT_COLOR.get(e, ELEMENT_COLOR[Element.PHYSICAL])
