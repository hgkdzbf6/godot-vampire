class_name EnemyTypes
extends RefCounted
## 敌人种类预设表。从 GameData.enemy_types 配置加载。

class Type:
	var max_hp: float
	var speed: float
	var dmg: float
	var xp: int
	var color: Color
	var elite: bool
	var weight: float
	var name: String
	var min_time: float
	var shape: String   # square / triangle / diamond / ghost / star
	var movement: String  # chase / charge / wander
	func _init(d: Dictionary) -> void:
		max_hp = float(d.get("max_hp", 20.0))
		speed = float(d.get("speed", 80.0))
		dmg = float(d.get("dmg", 8.0))
		xp = int(d.get("xp", 1))
		color = Color.from_string(d.get("color", "#9b3b3b"), Color("9b3b3b"))
		elite = bool(d.get("elite", false))
		weight = float(d.get("weight", 1.0))
		name = String(d.get("name", "敌人"))
		min_time = float(d.get("min_time", 0.0))
		shape = String(d.get("shape", "square"))
		movement = String(d.get("movement", "chase"))


## 返回当前可生成的敌人类型池。
## time: 当前关卡内已过时间；pool_min_time: 关卡允许的敌人最低解锁时间（关卡越高敌人越强）
static func pool_for(time: float, pool_min_time: float = 0.0) -> Array:
	var pool: Array = []
	for raw in GameData.raw().get("enemy_types", []):
		var t := Type.new(raw)
		# 敌人的解锁时间受关卡偏移影响：高关卡用更强的敌人池
		if time >= max(t.min_time - pool_min_time, 0.0):
			pool.append(t)
	return pool


## 按权重随机抽一个。
static func pick(pool: Array) -> Type:
	if pool.is_empty():
		return null
	var total := 0.0
	for t in pool:
		total += t.weight
	var r := randf() * total
	for t in pool:
		r -= t.weight
		if r <= 0.0:
			return t
	return pool[0]
