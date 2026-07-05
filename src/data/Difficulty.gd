extends Node
## 难度系统（Autoload）。
## 维护「当前生效的难度」，所有玩法系统读取 Difficulty.cur 的乘数。
## 支持预设档（轻松/普通/困难/噩梦）与自定义参数。

# 预设档
enum Preset { EASY, NORMAL, HARD, NIGHTMARE, CUSTOM }

const PRESET_NAME := {
	Preset.EASY: "轻松",
	Preset.NORMAL: "普通",
	Preset.HARD: "困难",
	Preset.NIGHTMARE: "噩梦",
	Preset.CUSTOM: "自定义",
}

const PRESET_DESC := {
	Preset.EASY: "怪物更弱更慢，适合熟悉玩法。推荐新手。",
	Preset.NORMAL: "标准平衡的挑战。",
	Preset.HARD: "怪物更强更快，升级更慢。",
	Preset.NIGHTMARE: "极致压迫，Boss 提前登场。仅供挑战。",
}


## 一份难度参数。所有字段都是「乘数」或「加成」，与 GameData 基础值相乘/相加。
class Params:
	# 玩家向（>1 对玩家有利）
	var player_damage_mult: float = 1.0      # 玩家剑伤害倍率
	var player_hp_mult: float = 1.0          # 玩家最大生命倍率
	var xp_mult: float = 1.0                 # 经验获取倍率
	# 敌人向（>1 对玩家不利）
	var enemy_hp_mult: float = 1.0           # 敌人血量倍率
	var enemy_damage_mult: float = 1.0       # 敌人伤害倍率
	var enemy_speed_mult: float = 1.0        # 敌人速度倍率
	var spawn_rate_mult: float = 1.0         # 刷怪频率倍率（>1 更频繁）
	var boss_hp_mult: float = 1.0            # Boss 血量倍率
	var boss_early_time: float = 0.0         # Boss 提前登场秒数（>0 提前）

	func clone() -> Params:
		var p := Params.new()
		p.player_damage_mult = player_damage_mult
		p.player_hp_mult = player_hp_mult
		p.xp_mult = xp_mult
		p.enemy_hp_mult = enemy_hp_mult
		p.enemy_damage_mult = enemy_damage_mult
		p.enemy_speed_mult = enemy_speed_mult
		p.spawn_rate_mult = spawn_rate_mult
		p.boss_hp_mult = boss_hp_mult
		p.boss_early_time = boss_early_time
		return p

	func to_dict() -> Dictionary:
		return {
			"player_damage_mult": player_damage_mult,
			"player_hp_mult": player_hp_mult,
			"xp_mult": xp_mult,
			"enemy_hp_mult": enemy_hp_mult,
			"enemy_damage_mult": enemy_damage_mult,
			"enemy_speed_mult": enemy_speed_mult,
			"spawn_rate_mult": spawn_rate_mult,
			"boss_hp_mult": boss_hp_mult,
			"boss_early_time": boss_early_time,
		}


## 生成一份预设档参数。
static func make_preset(preset: int) -> Params:
	var p := Params.new()
	match preset:
		Preset.EASY:
			p.player_damage_mult = 1.4
			p.player_hp_mult = 1.4
			p.xp_mult = 1.4
			p.enemy_hp_mult = 0.7
			p.enemy_damage_mult = 0.6
			p.enemy_speed_mult = 0.85
			p.spawn_rate_mult = 0.7
			p.boss_hp_mult = 0.7
		Preset.NORMAL:
			# 全部 1.0（默认）
			pass
		Preset.HARD:
			p.player_damage_mult = 0.9
			p.player_hp_mult = 0.9
			p.xp_mult = 0.85
			p.enemy_hp_mult = 1.4
			p.enemy_damage_mult = 1.4
			p.enemy_speed_mult = 1.15
			p.spawn_rate_mult = 1.3
			p.boss_hp_mult = 1.3
		Preset.NIGHTMARE:
			p.player_damage_mult = 0.8
			p.player_hp_mult = 0.8
			p.xp_mult = 0.75
			p.enemy_hp_mult = 2.0
			p.enemy_damage_mult = 1.8
			p.enemy_speed_mult = 1.3
			p.spawn_rate_mult = 1.6
			p.boss_hp_mult = 1.8
			p.boss_early_time = 60.0   # Boss 提前 60 秒
	return p


# 当前生效的难度
var current_preset: int = Preset.NORMAL
var current_params: Params = Params.new()


func _ready() -> void:
	# 默认普通
	set_preset(Preset.NORMAL)


func set_preset(preset: int) -> void:
	current_preset = preset
	current_params = make_preset(preset)


func set_custom(params: Params) -> void:
	current_preset = Preset.CUSTOM
	current_params = params


func preset_name(preset: int = -1) -> String:
	var p := preset if preset >= 0 else current_preset
	return PRESET_NAME.get(p, "普通")


func preset_desc(preset: int = -1) -> String:
	var p := preset if preset >= 0 else current_preset
	return PRESET_DESC.get(p, "")
