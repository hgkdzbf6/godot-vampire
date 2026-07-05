class_name Bestiary
extends Control
## 怪物图鉴。
## 展示所有怪物（按 5 档等级：低等/普通/精英/凶残/恶魔 显示数值与星级）
## 以及每关 Boss（技能、血量、伤害）。
## 数据全部来自配置：enemy_types + monster_grades + bestiary_bosses + stages。

signal back_requested()

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	# 应用 UI 缩放（递归缩放所有子控件的字号）
	UIScale.apply_font_scale(self)
	UIScale.scale_changed.connect(func(_s): UIScale.apply_font_scale(self))
	process_mode = Node.PROCESS_MODE_ALWAYS
	%BackButton.pressed.connect(func(): back_requested.emit())
	_populate()


func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	# 段标题：怪物
	_list.add_child(_make_section_title("怪物", Color("ffd24a")))
	var types: Array = GameData.raw().get("enemy_types", [])
	for i in types.size():
		var row := _make_monster_entry(types[i])
		_list.add_child(row)
	# 段标题：Boss
	_list.add_child(_make_section_title("Boss（每关）", Color("ff5a7a")))
	var bosses: Array = GameData.BESTIARY_BOSSES
	for i in bosses.size():
		var row := _make_boss_entry(bosses[i])
		_list.add_child(row)


# ============================================================
#  段标题
# ============================================================
func _make_section_title(text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = "—— %s ——" % text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


# ============================================================
#  怪物条目：形状预览 + 名称 + 5 档星级表
# ============================================================
func _make_monster_entry(raw: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_apply_row_bg(row)

	# 形状预览
	var preview := BestiaryPreview.new()
	preview.shape = String(raw.get("shape", "square"))
	preview.color = Color.from_string(String(raw.get("color", "#9b3b3b")), Color("9b3b3b"))
	preview.elite = bool(raw.get("elite", false))
	preview.custom_minimum_size = Vector2(80, 80)
	row.add_child(preview)

	# 信息列
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)

	# 名称 + 运动模式
	var name_lbl := Label.new()
	var nm: String = raw.get("name", "?")
	name_lbl.text = nm + "   ·   " + _movement_desc(String(raw.get("movement", "chase")))
	name_lbl.add_theme_color_override("font_color", Color.from_string(String(raw.get("color", "#cccccc")), Color.WHITE))
	name_lbl.add_theme_font_size_override("font_size", 20)
	info.add_child(name_lbl)

	# 5 档等级表
	var base_hp: float = float(raw.get("max_hp", 10))
	var base_dmg: float = float(raw.get("dmg", 5))
	var base_spd: float = float(raw.get("speed", 80))
	for g in GameData.MONSTER_GRADES:
		var line := _make_grade_line(g, base_hp, base_dmg, base_spd)
		info.add_child(line)

	row.add_child(info)
	return row


func _make_grade_line(grade: Dictionary, base_hp: float, base_dmg: float, base_spd: float) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	# 星级
	var stars: int = int(grade.get("stars", 1))
	var star_str := ""
	for i in stars:
		star_str += "★"
	var star_lbl := Label.new()
	star_lbl.text = star_str
	star_lbl.custom_minimum_size = Vector2(70, 0)
	# 按等级染色
	var scol := _grade_color(stars)
	star_lbl.add_theme_color_override("font_color", scol)
	star_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(star_lbl)
	# 等级名
	var gname := Label.new()
	gname.text = String(grade.get("name", ""))
	gname.custom_minimum_size = Vector2(56, 0)
	gname.add_theme_color_override("font_color", scol)
	gname.add_theme_font_size_override("font_size", 13)
	hbox.add_child(gname)
	# 数值（该档实际数值）
	var hp_mult: float = float(grade.get("hp_mult", 1.0))
	var dmg_mult: float = float(grade.get("dmg_mult", 1.0))
	var spd_mult: float = float(grade.get("speed_mult", 1.0))
	var stat := Label.new()
	stat.text = "生命 %d   伤害 %d   速度 %d" % [
		int(round(base_hp * hp_mult)),
		int(round(base_dmg * dmg_mult)),
		int(round(base_spd * spd_mult)),
	]
	stat.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	stat.add_theme_font_size_override("font_size", 13)
	hbox.add_child(stat)
	return hbox


func _grade_color(stars: int) -> Color:
	match stars:
		1: return Color(0.7, 0.72, 0.75)   # 低等 灰
		2: return Color(0.85, 0.88, 0.92)  # 普通 白
		3: return Color("4a9eff")           # 精英 蓝
		4: return Color("c062ff")           # 凶残 紫
		5: return Color("ffc83d")           # 恶魔 金
		_: return Color.WHITE


func _movement_desc(mv: String) -> String:
	match mv:
		"chase": return "追击"
		"charge": return "冲撞"
		"wander": return "游走"
		_: return mv


# ============================================================
#  Boss 条目：Boss 形状 + 名称 + 技能 + 属性
# ============================================================
func _make_boss_entry(raw: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_apply_row_bg(row)

	# Boss 形状预览（统一用大型怪形状）
	var preview := BestiaryPreview.new()
	preview.shape = "boss"
	preview.color = Color.from_string(String(raw.get("color", "#7a1f8f")), Color("7a1f8f"))
	preview.elite = true
	preview.custom_minimum_size = Vector2(96, 96)
	row.add_child(preview)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	# 名称 + 关卡
	var name_lbl := Label.new()
	name_lbl.text = "★ %s（第 %d 关 Boss）" % [String(raw.get("name", "?")), int(raw.get("stage", 1))]
	name_lbl.add_theme_color_override("font_color", Color.from_string(String(raw.get("color", "#cccccc")), Color.WHITE))
	name_lbl.add_theme_font_size_override("font_size", 22)
	info.add_child(name_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = String(raw.get("desc", ""))
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# 属性
	var stat_lbl := Label.new()
	stat_lbl.text = "生命 %d   接触伤害 %d" % [int(raw.get("max_hp", 0)), int(raw.get("contact_damage", 0))]
	stat_lbl.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	stat_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(stat_lbl)

	# 技能
	var skills: Array = raw.get("skills", [])
	var skill_str := "、".join(skills)
	var skill_lbl := Label.new()
	skill_lbl.text = "技能：" + skill_str
	skill_lbl.add_theme_color_override("font_color", Color("ff8a5a"))
	skill_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(skill_lbl)

	row.add_child(info)
	return row


func _apply_row_bg(row: HBoxContainer) -> void:
	var idx := row.get_index()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.2, 0.85 if idx % 2 == 0 else 0.55)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	row.add_theme_stylebox_override("panel", sb)
