class_name UpgradeDefs
extends RefCounted
## 升级定义表。每条升级是一个 Dictionary，玩家选择后通过 GameEvents.upgrade_applied 广播，
## 由 Player / SwordManager 各自根据 id 处理。
##
## 字段说明：
##   id       : 唯一标识，Player/SwordManager 据此应用效果
##   title    : 技能名称（卡牌第三层）
##   value_str: 强化数值显示串（卡牌第四层，醒目颜色）
##   desc     : 一句话说明（卡牌第五层）
##   icon     : 图标符号标识（剑/盾/鞋/闪电/火焰/冰/十字/...）
##   rarity   : 稀有度 common/fine/rare/epic/legendary（卡牌第一层 + 边框配色）
##   cat      : 类别（用于配色辅助）

# 升级类别
enum Category { SWORD, OFFENSE, DEFENSE, UTILITY, ELEMENT }

# 稀有度档位（按你的规范：普通白 / 优秀绿 / 稀有蓝 / 史诗紫 / 传说金）
enum Rarity { COMMON, FINE, RARE, EPIC, LEGENDARY }

const RARITY_NAME := {
	Rarity.COMMON: "普通",
	Rarity.FINE: "优秀",
	Rarity.RARE: "稀有",
	Rarity.EPIC: "史诗",
	Rarity.LEGENDARY: "传说",
}

const RARITY_COLOR := {
	Rarity.COMMON: Color("d8d8d8"),      # 白
	Rarity.FINE: Color("7ed957"),         # 绿
	Rarity.RARE: Color("4a9eff"),         # 蓝
	Rarity.EPIC: Color("c062ff"),         # 紫
	Rarity.LEGENDARY: Color("ffc83d"),    # 金
}


const ALL := [
	# ---- 剑成长 ----
	{
		"id": "sword_count", "cat": Category.SWORD, "rarity": "epic",
		"title": "飞剑术", "value_str": "+1 剑", "icon": "sword",
		"desc": "增加一把环绕飞剑",
		"value": 1, "max_stacks": 7,
	},
	{
		"id": "sword_radius", "cat": Category.SWORD, "rarity": "common",
		"title": "剑气延伸", "value_str": "+20%", "icon": "radius",
		"desc": "剑的旋转半径增大",
		"mult": 1.2,
	},
	{
		"id": "sword_rot_speed", "cat": Category.SWORD, "rarity": "common",
		"title": "疾速旋转", "value_str": "+25%", "icon": "spin",
		"desc": "剑转得更快，DPS 提升",
		"mult": 1.25,
	},
	{
		"id": "sword_size", "cat": Category.SWORD, "rarity": "fine",
		"title": "巨剑化", "value_str": "+25%", "icon": "sword_big",
		"desc": "剑身变大，更容易命中",
		"mult": 1.25,
	},
	{
		"id": "sword_pierce", "cat": Category.SWORD, "rarity": "rare",
		"title": "穿透打击", "value_str": "+1", "icon": "pierce",
		"desc": "剑可同时多命中一个目标",
		"value": 1, "max_stacks": 4,
	},
	{
		"id": "sword_damage", "cat": Category.OFFENSE, "rarity": "common",
		"title": "锋利之刃", "value_str": "+30%", "icon": "sword",
		"desc": "单次命中伤害提升",
		"mult": 1.3,
	},
	# ---- 进攻 ----
	{
		"id": "crit_chance", "cat": Category.OFFENSE, "rarity": "fine",
		"title": "致命一击", "value_str": "+12%", "icon": "crit",
		"desc": "暴击率提升，概率造成双倍伤害",
		"value": 0.12,
	},
	{
		"id": "crit_mult", "cat": Category.OFFENSE, "rarity": "rare",
		"title": "暴击精通", "value_str": "+0.3x", "icon": "crit",
		"desc": "暴击伤害倍率提高",
		"value": 0.3,
	},
	{
		"id": "knockback", "cat": Category.OFFENSE, "rarity": "common",
		"title": "强力击退", "value_str": "+50%", "icon": "knockback",
		"desc": "推开敌人更远",
		"mult": 1.5,
	},
	{
		"id": "lifesteal", "cat": Category.OFFENSE, "rarity": "epic",
		"title": "吸血鬼之吻", "value_str": "+1", "icon": "vampire",
		"desc": "每次命中回复 1 点生命（仅轻松难度）",
		"value": 1.0, "max_stacks": 5, "easy_only": true,
	},
	# ---- 元素 ----
	{
		"id": "element_fire", "cat": Category.ELEMENT, "rarity": "epic",
		"title": "炽焰附魔", "value_str": "火焰", "icon": "fire",
		"desc": "剑附加火焰，持续灼烧敌人",
		"value": 0.5,
	},
	{
		"id": "element_frost", "cat": Category.ELEMENT, "rarity": "epic",
		"title": "寒冰附魔", "value_str": "冰冻", "icon": "frost",
		"desc": "剑附加冰冻，减缓敌人移速",
		"value": 0.5,
	},
	{
		"id": "element_lightning", "cat": Category.ELEMENT, "rarity": "epic",
		"title": "雷电附魔", "value_str": "雷电", "icon": "lightning",
		"desc": "剑附加雷电，连锁附近敌人",
		"value": 0.3,
	},
	# ---- 防御 / 生存 ----
	{
		"id": "max_hp", "cat": Category.DEFENSE, "rarity": "common",
		"title": "强健体魄", "value_str": "+25 HP", "icon": "heart",
		"desc": "最大生命提升并立即回血",
		"value": 25,
	},
	{
		"id": "regen", "cat": Category.DEFENSE, "rarity": "rare",
		"title": "再生", "value_str": "+1 HP/秒", "icon": "shield",
		"desc": "每秒恢复 1 点生命值",
		"value": 1.0, "max_stacks": 5,
	},
	{
		"id": "dodge", "cat": Category.DEFENSE, "rarity": "rare",
		"title": "灵巧身法", "value_str": "+6%", "icon": "dodge",
		"desc": "概率完全规避一次伤害",
		"value": 0.06,
	},
	# ---- 工具 ----
	{
		"id": "move_speed", "cat": Category.UTILITY, "rarity": "common",
		"title": "疾跑", "value_str": "+12%", "icon": "boot",
		"desc": "提高移动速度，更容易躲避攻击",
		"mult": 1.12,
	},
	{
		"id": "pickup_range", "cat": Category.UTILITY, "rarity": "common",
		"title": "磁力强化", "value_str": "+50", "icon": "lightning",
		"desc": "扩大经验水晶吸附范围",
		"value": 50.0,
	},
	{
		"id": "heal_full", "cat": Category.UTILITY, "rarity": "rare",
		"title": "神圣治愈", "value_str": "满血", "icon": "cross",
		"desc": "立即回复全部生命值",
		"value": 1, "max_stacks": 1,
	},
]


## 把字符串稀有度转成枚举。
static func rarity_of(u: Dictionary) -> int:
	var r: String = u.get("rarity", "common")
	match r:
		"common": return Rarity.COMMON
		"fine": return Rarity.FINE
		"rare": return Rarity.RARE
		"epic": return Rarity.EPIC
		"legendary": return Rarity.LEGENDARY
		_: return Rarity.COMMON


static func rarity_color(r: int) -> Color:
	return RARITY_COLOR.get(r, RARITY_COLOR[Rarity.COMMON])


static func rarity_name(r: int) -> String:
	return RARITY_NAME.get(r, "普通")


## 从全表中随机抽取 n 个互不重复的升级。
## 尊重 max_stacks 计数；easy_only 项仅在轻松难度出现。
static func roll(count: int, taken: Dictionary, difficulty_preset: int = 1) -> Array:
	var pool: Array = []
	var is_easy := difficulty_preset == 0   # 0 = EASY
	for u in ALL:
		var idd: String = u["id"]
		# 易限项：非轻松难度跳过
		if u.get("easy_only", false) and not is_easy:
			continue
		if u.has("max_stacks"):
			var taken_n: int = taken.get(idd, 0)
			if taken_n >= int(u["max_stacks"]):
				continue
		pool.append(u)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
