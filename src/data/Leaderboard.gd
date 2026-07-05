extends Node
## 排行榜（Autoload）。持久化到 user://leaderboard.json。
## 每条记录：{ name, score, difficulty, time, kills, level, boss_defeated, date }
## 按分数降序保留 Top 20。

const FILE_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 20
const SCORE_PER_KILL := 12
const SCORE_PER_LEVEL := 50
const SCORE_PER_SECOND := 2
const BOSS_DEFEAT_BONUS := 2000

# 难度分数系数（高难度得分更高）
const DIFFICULTY_SCORE_MULT := {
	0: 1.0,   # EASY
	1: 1.5,   # NORMAL
	2: 2.2,   # HARD
	3: 3.5,   # NIGHTMARE
	4: 2.0,   # CUSTOM
}

var _entries: Array = []


func _ready() -> void:
	_load()


## 计算一局游戏的分数。
func compute_score(time_sec: float, kills: int, level: int, boss_defeated: bool, difficulty_preset: int) -> int:
	var base := time_sec * SCORE_PER_SECOND + kills * SCORE_PER_KILL + level * SCORE_PER_LEVEL
	if boss_defeated:
		base += BOSS_DEFEAT_BONUS
	var mult: float = DIFFICULTY_SCORE_MULT.get(difficulty_preset, 1.0)
	return int(round(base * mult))


## 提交一条记录，返回它的排名（从 1 开始）；未进榜返回 -1。
func submit(name: String, score: int, difficulty: int, time_sec: float, kills: int, level: int, boss_defeated: bool) -> int:
	var entry := {
		"name": name.strip_edges().substr(0, 12) if name.strip_edges() != "" else "无名英雄",
		"score": score,
		"difficulty": difficulty,
		"time": int(time_sec),
		"kills": kills,
		"level": level,
		"boss": bool(boss_defeated),
		"date": Time.get_datetime_string_from_system(false, true),
	}
	_entries.append(entry)
	_entries.sort_custom(_sort_desc)
	# 截断到 MAX_ENTRIES
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_save()
	var rank := _entries.find(entry) + 1
	return rank if rank <= MAX_ENTRIES else -1


func _sort_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))


func get_entries() -> Array:
	return _entries.duplicate(true)


func clear() -> void:
	_entries.clear()
	_save()


func _load() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Array:
		_entries = json.data


func _save() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Leaderboard] 无法写入排行榜文件: %s" % FILE_PATH)
		return
	f.store_string(JSON.stringify(_entries, "\t"))
	f.close()
