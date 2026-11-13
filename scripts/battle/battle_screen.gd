extends Control

const CreaturePortrait = preload("res://scripts/battle/creature_portrait.gd")
const BATTLE_SIMULATOR = preload("res://scripts/battle/battle_simulator.gd")
const MONSTER_CATALOG = preload("res://data/monsters/catalog.tres")
const DEFAULT_ROSTER = preload("res://data/player/default_roster.tres")
const ENCOUNTER_CATALOG = preload("res://data/encounters/catalog.tres")
const PLAYER_SAVE = preload("res://scripts/data/player_save.gd")
const STAR_STAT_MULTIPLIERS: Array[float] = [1.0, 1.12, 1.26, 1.42, 1.60, 1.82, 2.08, 2.40, 2.80, 3.50]
const STAR_SPD_MULTIPLIERS: Array[float] = [1.0, 1.03, 1.06, 1.09, 1.12, 1.15, 1.18, 1.21, 1.24, 1.27]
const RARITY_BONUS := {"Common": 0.0, "Uncommon": 0.02, "Rare": 0.04, "Epic": 0.06, "Legendary": 0.08, "Mythical": 0.10}
const RARITY_SPEED_BONUS := {"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4, "Mythical": 5}
const CAPTURE_BASE := {"Common": 0.50, "Uncommon": 0.35, "Rare": 0.20, "Epic": 0.10, "Legendary": 0.03}
const CONTRACT_MULTIPLIER := {"Basic": 1.0, "Advanced": 1.5, "Master": 2.5}

var allies: Array = []
var enemies: Array = []
var owned_roster: Array[Dictionary] = []
var formation_checks: Array[CheckBox] = []
var formation_message: Label
var formation_root: Control
var player_profile: Dictionary = {}
var selected_encounter: Resource
var encounter_select_root: Control
var gauges: Array[int] = []
var selected_target := 0
var selected_enemy := 0
var current_actor := -1
var turns_taken := 0
var max_rounds := 30
var capture_pity := 0.0
var selected_contract := "Basic"
var battle_over := false
var outcome := ""
var rewards_claimed := false
var reward_lines: Array[String] = []
var random_source := RandomNumberGenerator.new()
var action_delay := 0.35
var action_in_progress := false
var battle_start_notice := ""

var ally_buttons: Array[Button] = []
var action_buttons: Array[Button] = []

var round_label: Label
var turn_status_label: Label
var turn_queue_label: Label
var log_label: RichTextLabel
var restart_button: Button
var auto_toggle: CheckBox
var full_auto_toggle: CheckBox
var speed_picker: OptionButton
var contract_picker: OptionButton
var end_battle_overlay: ColorRect
var end_battle_title: Label
var end_battle_body: Label
var end_battle_close_button: Button
var ally_hp_bars: Array[ProgressBar] = []
var ally_energy_bars: Array[ProgressBar] = []
var ally_gauge_bars: Array[ProgressBar] = []
var ally_detail_labels: Array[Label] = []
var ally_effect_labels: Array[Label] = []
var ally_cards: Array[PanelContainer] = []
var enemy_target_buttons: Array[Button] = []
var enemy_detail_labels: Array[Label] = []
var enemy_hp_bars: Array[ProgressBar] = []
var enemy_gauge_bars: Array[ProgressBar] = []
var enemy_effect_labels: Array[Label] = []
var enemy_cards: Array[PanelContainer] = []
var acting_enemy_index := -1

func _ready() -> void:
	player_profile = PLAYER_SAVE.load_or_create(DEFAULT_ROSTER)
	_build_encounter_select_screen()

func _build_encounter_select_screen() -> void:
	encounter_select_root = Control.new()
	encounter_select_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(encounter_select_root)
	var background := ColorRect.new()
	background.color = Color("#101817")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_select_root.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_select_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 440)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d2a27"), Color("#3e6256")))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "CHỌN TRẬN ĐẤU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	var instruction := Label.new()
	instruction.text = "Chọn một cuộc chạm trán trong Ancient Forest."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(instruction)
	var back_button := Button.new()
	back_button.text = "←  Về căn cứ"
	back_button.custom_minimum_size = Vector2(0, 42)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/base/Base.tscn"))
	layout.add_child(back_button)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	layout.add_child(list)
	for encounter in ENCOUNTER_CATALOG.encounters:
		var enemy_entries: Array = _resource_value(encounter, &"enemies", [])
		var button := Button.new()
		button.text = "%s  ·  %d địch" % [str(_resource_value(encounter, &"display_name", "Trận đấu")), enemy_entries.size()]
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_on_encounter_selected.bind(encounter))
		list.add_child(button)
	var note := Label.new()
	note.text = "Mỗi trận lấy chỉ số địch từ danh mục quái vật."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(note)

func _on_encounter_selected(encounter: Resource) -> void:
	selected_encounter = encounter
	encounter_select_root.queue_free()
	_build_formation_screen()

func _build_formation_screen() -> void:
	owned_roster.clear()
	formation_checks.clear()
	var active_team: Array = player_profile.get("team", [])
	var stored_creatures: Array = player_profile.get("storage", [])
	var expedition: Dictionary = player_profile.get("expedition", {})
	var traveling_ids: Dictionary = {}
	if bool(expedition.get("active", false)):
		for instance_id in expedition.get("squad_ids", []):
			traveling_ids[str(instance_id)] = true
	for creature in active_team:
		if not traveling_ids.has(str(creature.get("instance_id", ""))):
			owned_roster.append(creature.duplicate(true))
	for creature in stored_creatures:
		if not traveling_ids.has(str(creature.get("instance_id", ""))):
			owned_roster.append(creature.duplicate(true))

	var max_allies := int(_resource_value(selected_encounter, &"max_allies", 3))
	formation_root = Control.new()
	formation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(formation_root)
	var background := ColorRect.new()
	background.color = Color("#101817")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	formation_root.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	formation_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 440)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d2a27"), Color("#3e6256")))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "CHỌN ĐỘI HÌNH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	var instruction := Label.new()
	instruction.text = "Chọn từ 1 đến %d quái. Quái đang Viễn Chinh không thể tham chiến." % max_allies
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(instruction)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(list)
	for index in range(owned_roster.size()):
		var entry: Dictionary = owned_roster[index]
		var monster_id := StringName(str(entry.get("monster_id", "")))
		var definition: Resource = MONSTER_CATALOG.find_monster(monster_id)
		var monster_name := str(_resource_value(definition, &"display_name", monster_id)) if definition != null else str(monster_id)
		var check := CheckBox.new()
		check.text = "%s  ·  Sao %d  ·  EXP huấn luyện %d" % [monster_name, int(entry.get("star_rank", 1)), int(entry.get("training_exp", 0))]
		check.button_pressed = index < active_team.size()
		var check_index := index
		check.toggled.connect(func(pressed: bool): _on_formation_toggled(check_index, pressed))
		list.add_child(check)
		formation_checks.append(check)
	formation_message = Label.new()
	formation_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(formation_message)
	var start_button := Button.new()
	start_button.text = "Bắt đầu trận"
	start_button.custom_minimum_size = Vector2(0, 44)
	start_button.pressed.connect(_on_formation_confirmed)
	layout.add_child(start_button)
	_refresh_formation_message()

func _on_formation_toggled(index: int, pressed: bool) -> void:
	if pressed:
		var selected_count := 0
		for check in formation_checks:
			if check.button_pressed:
				selected_count += 1
		var max_allies := int(_resource_value(selected_encounter, &"max_allies", 3))
		if selected_count > max_allies:
			formation_checks[index].set_pressed_no_signal(false)
	_refresh_formation_message()

func _refresh_formation_message() -> void:
	if not is_instance_valid(formation_message):
		return
	var selected_count := 0
	for check in formation_checks:
		if check.button_pressed:
			selected_count += 1
	var max_allies := int(_resource_value(selected_encounter, &"max_allies", 3))
	formation_message.text = "Đang chọn %d / %d quái." % [selected_count, max_allies]

func _on_formation_confirmed() -> void:
	var selected_team: Array[Dictionary] = []
	var reserve: Array[Dictionary] = []
	for index in range(owned_roster.size()):
		if formation_checks[index].button_pressed:
			selected_team.append(owned_roster[index])
		else:
			reserve.append(owned_roster[index])
	var expedition: Dictionary = player_profile.get("expedition", {})
	if bool(expedition.get("active", false)):
		var traveling_ids: Dictionary = {}
		for instance_id in expedition.get("squad_ids", []):
			traveling_ids[str(instance_id)] = true
		for creature in player_profile.get("team", []):
			if traveling_ids.has(str(creature.get("instance_id", ""))):
				reserve.append(creature.duplicate(true))
		for creature in player_profile.get("storage", []):
			if traveling_ids.has(str(creature.get("instance_id", ""))):
				reserve.append(creature.duplicate(true))
	if selected_team.is_empty():
		formation_message.text = "Hãy chọn ít nhất một quái."
		return
	player_profile["team"] = selected_team
	player_profile["storage"] = reserve
	PLAYER_SAVE.save(player_profile)
	formation_root.queue_free()
	if not _start_battle():
		return
	_build_screen()
	if not battle_start_notice.is_empty():
		_add_log(battle_start_notice)
	_refresh()
	_advance_to_next_turn()

func _start_battle() -> bool:
	player_profile = PLAYER_SAVE.load_or_create(DEFAULT_ROSTER)
	battle_start_notice = ""
	if str(_resource_value(selected_encounter, &"encounter_id", "")) == "ancient_forest_capture_spot" and not bool(player_profile.get("tutorial_capture_contracts_granted", false)):
		var inventory: Dictionary = player_profile.get("inventory", {})
		inventory["monster_contract_basic"] = maxi(3, int(inventory.get("monster_contract_basic", 0)))
		player_profile["inventory"] = inventory
		player_profile["tutorial_capture_contracts_granted"] = true
		battle_start_notice = "Bạn nhận được 3 Hợp đồng Cơ bản cho Capture Spot hướng dẫn."
		PLAYER_SAVE.save(player_profile)
	var roster: Array = player_profile.get("team", [])
	var enemy_entries: Array = _resource_value(selected_encounter, &"enemies", [])
	var max_allies := int(_resource_value(selected_encounter, &"max_allies", 3))
	var max_enemies := int(_resource_value(selected_encounter, &"max_enemies", 3))
	if roster.is_empty() or roster.size() > max_allies or enemy_entries.is_empty() or enemy_entries.size() > max_enemies:
		push_error("Số quái trong đội hoặc phe địch vượt quá giới hạn của trận.")
		return false

	allies.clear()
	enemies.clear()
	var starting_energy: int = int(_resource_value(selected_encounter, &"starting_energy", 30))
	for roster_entry in roster:
		var monster_id := StringName(str(roster_entry.get("monster_id", "")))
		var definition: Resource = MONSTER_CATALOG.find_monster(monster_id)
		if definition == null:
			push_error("Không tìm thấy quái '%s' trong danh mục." % monster_id)
			return false
		var ally := _make_combatant(definition, int(roster_entry.get("star_rank", 1)), starting_energy)
		ally["training_exp"] = int(roster_entry.get("training_exp", 0))
		if ally["skills"].size() < 2:
			push_error("Quái '%s' cần có ít nhất hai kỹ năng." % monster_id)
			return false
		allies.append(ally)

	for encounter_entry in enemy_entries:
		var enemy_unit := _make_encounter_combatant(encounter_entry, starting_energy)
		if enemy_unit.is_empty():
			return false
		enemies.append(enemy_unit)

	max_rounds = int(_resource_value(selected_encounter, &"max_rounds", 30))
	gauges.clear()
	gauges.resize(allies.size() + enemies.size())
	gauges.fill(0)
	selected_target = 0
	selected_enemy = 0
	current_actor = -1
	acting_enemy_index = -1
	action_in_progress = false
	turns_taken = 0
	capture_pity = 0.0
	selected_contract = "Basic"
	battle_over = false
	outcome = ""
	rewards_claimed = false
	reward_lines.clear()
	random_source.randomize()
	return true

func _resource_value(resource: Resource, property: StringName, fallback: Variant = null) -> Variant:
	var value: Variant = resource.get(property)
	if value == null:
		return fallback
	return value

func _make_encounter_combatant(entry: Resource, starting_energy: int) -> Dictionary:
	var monster_id := StringName(str(_resource_value(entry, &"monster_id", "")))
	var definition: Resource = MONSTER_CATALOG.find_monster(monster_id)
	if definition == null:
		push_error("Không tìm thấy quái địch '%s' trong danh mục." % monster_id)
		return {}
	var unit := _make_combatant(definition, int(_resource_value(entry, &"star_rank", 1)), starting_energy)
	unit["capturable"] = _resource_value(definition, &"capturable", false)
	var exp_override: int = int(_resource_value(entry, &"exp_reward_override", -1))
	unit["exp_reward"] = exp_override if exp_override >= 0 else int(_resource_value(definition, &"exp_reward", 0))
	var loot_override: Array = _resource_value(entry, &"loot_table_override", [])
	var loot_source: Array = loot_override if not loot_override.is_empty() else _resource_value(definition, &"loot_table", [])
	unit["loot_table"] = _convert_loot_table(loot_source)
	unit["captured"] = false
	return unit

func _make_combatant(definition: Resource, star_rank: int, starting_energy: int) -> Dictionary:
	var star_index := clampi(star_rank - 1, 0, STAR_STAT_MULTIPLIERS.size() - 1)
	var star_multiplier: float = STAR_STAT_MULTIPLIERS[star_index]
	var speed_multiplier: float = STAR_SPD_MULTIPLIERS[star_index]
	var rarity: String = str(_resource_value(definition, &"rarity", "Common"))
	var rarity_multiplier := 1.0 + float(RARITY_BONUS.get(rarity, 0.0))
	var skills: Array[Dictionary] = []
	for skill_data in _resource_value(definition, &"skills", []):
		skills.append({
			"id": str(_resource_value(skill_data, &"skill_id", "")),
			"name": str(_resource_value(skill_data, &"display_name", "")),
			"description": str(_resource_value(skill_data, &"description", "")),
			"cost": int(_resource_value(skill_data, &"energy_cost", 0)),
			"effect": str(_resource_value(skill_data, &"effect_type", "damage")),
			"multiplier": float(_resource_value(skill_data, &"multiplier", 1.0)),
			"duration": int(_resource_value(skill_data, &"duration", 0)),
			"regen_multiplier": float(_resource_value(skill_data, &"regen_multiplier", 0.0)),
			"shield_percent": float(_resource_value(skill_data, &"shield_percent", 0.0)),
			"defense_modifier": float(_resource_value(skill_data, &"defense_modifier", 0.0)),
			"target": str(_resource_value(skill_data, &"target", "enemy"))
		})
	var max_hp := roundi(float(_resource_value(definition, &"base_hp", 1)) * star_multiplier * rarity_multiplier)
	return {
		"id": str(_resource_value(definition, &"monster_id", "")),
		"name": str(_resource_value(definition, &"display_name", "")),
		"element": str(_resource_value(definition, &"element", "Nature")),
		"role": str(_resource_value(definition, &"role", "Attacker")),
		"rarity": rarity,
		"star_rank": star_index + 1,
		"hp": max_hp,
		"max_hp": max_hp,
		"atk": roundi(float(_resource_value(definition, &"base_atk", 1)) * star_multiplier * rarity_multiplier),
		"def": roundi(float(_resource_value(definition, &"base_def", 1)) * star_multiplier * rarity_multiplier),
		"spd": roundi(float(_resource_value(definition, &"base_spd", 1)) * speed_multiplier) + int(RARITY_SPEED_BONUS.get(rarity, 0)),
		"energy": starting_energy,
		"shield": 0,
		"effects": [],
		"training_exp": 0,
		"passive": str(_resource_value(definition, &"passive_id", "")),
		"passive_name": str(_resource_value(definition, &"passive_name", "")),
		"skills": skills,
		"capturable": bool(_resource_value(definition, &"capturable", true)),
		"exp_reward": int(_resource_value(definition, &"exp_reward", 0)),
		"loot_table": []
	}

func _convert_loot_table(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for drop in source:
		result.append({
			"item_id": str(_resource_value(drop, &"item_id", "unknown")),
			"item": str(_resource_value(drop, &"display_name", "Vật phẩm")),
			"chance": float(_resource_value(drop, &"chance", 1.0)),
			"min": int(_resource_value(drop, &"quantity_min", 1)),
			"max": int(_resource_value(drop, &"quantity_max", 1))
		})
	return result

func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#101817")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "THE LAST HAVEN"
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	round_label = Label.new()
	round_label.custom_minimum_size = Vector2(170, 0)
	header.add_child(round_label)
	auto_toggle = CheckBox.new()
	auto_toggle.text = "Auto"
	auto_toggle.tooltip_text = "Tự dùng đòn thường và Kỹ năng 1. Kỹ năng 2 và thu phục do bạn chọn."
	auto_toggle.toggled.connect(_on_auto_toggled)
	header.add_child(auto_toggle)
	full_auto_toggle = CheckBox.new()
	full_auto_toggle.text = "Auto toàn phần"
	full_auto_toggle.tooltip_text = "Cho phép Auto tự dùng cả Kỹ năng 2. Không tự thu phục."
	full_auto_toggle.toggled.connect(_on_full_auto_toggled)
	header.add_child(full_auto_toggle)
	speed_picker = OptionButton.new()
	speed_picker.add_item("Tốc độ x1", 1)
	speed_picker.add_item("Tốc độ x2", 2)
	speed_picker.add_item("Tốc độ x3", 3)
	speed_picker.item_selected.connect(_on_speed_changed)
	header.add_child(speed_picker)

	var turn_panel := PanelContainer.new()
	turn_panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d2a27"), Color("#3e6256")))
	layout.add_child(turn_panel)
	var turn_layout := VBoxContainer.new()
	turn_layout.add_theme_constant_override("separation", 3)
	turn_panel.add_child(turn_layout)
	turn_status_label = Label.new()
	turn_status_label.add_theme_font_size_override("font_size", 15)
	turn_layout.add_child(turn_status_label)
	turn_queue_label = Label.new()
	turn_queue_label.add_theme_color_override("font_color", Color("#b7c9c1"))
	turn_layout.add_child(turn_queue_label)

	var sides := HBoxContainer.new()
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sides.add_theme_constant_override("separation", 14)
	layout.add_child(sides)

	var team_column := VBoxContainer.new()
	team_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_column.size_flags_stretch_ratio = 1.2
	team_column.add_theme_constant_override("separation", 7)
	sides.add_child(team_column)
	var team_title := Label.new()
	team_title.text = "ĐỘI CỦA BẠN  ·  %d QUÁI" % allies.size()
	team_title.add_theme_font_size_override("font_size", 18)
	team_column.add_child(team_title)
	var ally_scroll := ScrollContainer.new()
	ally_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	team_column.add_child(ally_scroll)
	var ally_list := VBoxContainer.new()
	ally_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ally_list.add_theme_constant_override("separation", 7)
	ally_scroll.add_child(ally_list)
	for index in range(allies.size()):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 104)
		card.add_theme_stylebox_override("panel", _panel_style(Color("#202c29"), Color("#385247")))
		ally_list.add_child(card)
		ally_cards.append(card)
		var card_body := HBoxContainer.new()
		card_body.add_theme_constant_override("separation", 10)
		card.add_child(card_body)
		var portrait = CreaturePortrait.new()
		portrait.custom_minimum_size = Vector2(70, 70)
		portrait.call("setup", allies[index]["name"])
		card_body.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 2)
		card_body.add_child(details)
		var ally_button := Button.new()
		ally_button.flat = true
		ally_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ally_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ally_index := index
		ally_button.pressed.connect(func(): _select_target(ally_index))
		details.add_child(ally_button)
		ally_buttons.append(ally_button)
		var detail := Label.new()
		details.add_child(detail)
		ally_detail_labels.append(detail)
		var hp_bar := _new_bar(Color("#79c77f"), 8)
		details.add_child(hp_bar)
		ally_hp_bars.append(hp_bar)
		var energy_bar := _new_bar(Color("#64b9e6"), 6)
		details.add_child(energy_bar)
		ally_energy_bars.append(energy_bar)
		var gauge_bar := _new_bar(Color("#e4bd68"), 5)
		details.add_child(gauge_bar)
		ally_gauge_bars.append(gauge_bar)
		var effects := Label.new()
		effects.add_theme_font_size_override("font_size", 10)
		details.add_child(effects)
		ally_effect_labels.append(effects)

	var versus_column := VBoxContainer.new()
	versus_column.custom_minimum_size = Vector2(58, 0)
	versus_column.alignment = BoxContainer.ALIGNMENT_CENTER
	sides.add_child(versus_column)
	var versus := Label.new()
	versus.text = "VS"
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.add_theme_font_size_override("font_size", 25)
	versus.add_theme_color_override("font_color", Color("#e0b36a"))
	versus_column.add_child(versus)
	var clash := Label.new()
	clash.text = "-->"
	clash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash.add_theme_font_size_override("font_size", 25)
	clash.add_theme_color_override("font_color", Color("#dd856d"))
	versus_column.add_child(clash)

	var enemy_column := VBoxContainer.new()
	enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_column.size_flags_stretch_ratio = 0.85
	enemy_column.add_theme_constant_override("separation", 7)
	sides.add_child(enemy_column)
	var enemy_title := Label.new()
	enemy_title.text = "KẺ ĐỊCH  ·  %d QUÁI" % enemies.size()
	enemy_title.add_theme_font_size_override("font_size", 18)
	enemy_column.add_child(enemy_title)
	var enemy_scroll := ScrollContainer.new()
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_column.add_child(enemy_scroll)
	var enemy_list := VBoxContainer.new()
	enemy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_list.add_theme_constant_override("separation", 7)
	enemy_scroll.add_child(enemy_list)
	for index in range(enemies.size()):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.add_theme_stylebox_override("panel", _panel_style(Color("#302522"), Color("#865544")))
		enemy_list.add_child(card)
		enemy_cards.append(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var portrait = CreaturePortrait.new()
		portrait.custom_minimum_size = Vector2(62, 62)
		portrait.call("setup", enemies[index]["name"])
		row.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 1)
		row.add_child(details)
		var target_button := Button.new()
		target_button.flat = true
		target_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		target_button.custom_minimum_size = Vector2(0, 20)
		var enemy_index := index
		target_button.pressed.connect(func(): _select_enemy(enemy_index))
		details.add_child(target_button)
		enemy_target_buttons.append(target_button)
		var detail := Label.new()
		detail.add_theme_font_size_override("font_size", 11)
		details.add_child(detail)
		enemy_detail_labels.append(detail)
		var hp_bar := _new_bar(Color("#dc715d"), 9)
		details.add_child(hp_bar)
		enemy_hp_bars.append(hp_bar)
		var gauge_bar := _new_bar(Color("#e4bd68"), 5)
		details.add_child(gauge_bar)
		enemy_gauge_bars.append(gauge_bar)
		var effects := Label.new()
		effects.add_theme_font_size_override("font_size", 9)
		details.add_child(effects)
		enemy_effect_labels.append(effects)

	var actions_title := Label.new()
	actions_title.text = "CHỌN HÀNH ĐỘNG  ·  NHẤP QUÁI ĐỊCH ĐỂ CHỌN MỤC TIÊU, NHẤP ĐỒNG MINH ĐỂ CHỌN MỤC TIÊU HỒI MÁU"
	actions_title.add_theme_font_size_override("font_size", 18)
	layout.add_child(actions_title)
	contract_picker = OptionButton.new()
	contract_picker.add_item("Hợp đồng Cơ bản")
	contract_picker.set_item_metadata(0, "Basic")
	contract_picker.add_item("Hợp đồng Nâng cao")
	contract_picker.set_item_metadata(1, "Advanced")
	contract_picker.add_item("Hợp đồng Bậc thầy")
	contract_picker.set_item_metadata(2, "Master")
	contract_picker.item_selected.connect(_on_contract_selected)
	layout.add_child(contract_picker)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	var action_names := ["Đánh thường", "Kỹ năng 1", "Kỹ năng 2", "Thu phục"]
	for index in range(action_names.size()):
		var action_button := Button.new()
		action_button.text = action_names[index]
		action_button.custom_minimum_size = Vector2(0, 48)
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_index := index
		if action_index == 3:
			action_button.pressed.connect(func(): _act(action_index))
		else:
			action_button.pressed.connect(func(): _act(action_index))
		actions.add_child(action_button)
		action_buttons.append(action_button)

	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 72)
	log_label.scroll_following = true
	layout.add_child(log_label)

	restart_button = Button.new()
	restart_button.text = "Về căn cứ"
	restart_button.visible = false
	restart_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/base/Base.tscn"))
	layout.add_child(restart_button)
	_build_end_battle_overlay()

func _build_end_battle_overlay() -> void:
	end_battle_overlay = ColorRect.new()
	end_battle_overlay.color = Color(0.02, 0.04, 0.04, 0.78)
	end_battle_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_battle_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_battle_overlay.visible = false
	add_child(end_battle_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_battle_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 300)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d2a27"), Color("#d8b56c")))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	end_battle_title = Label.new()
	end_battle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_battle_title.add_theme_font_size_override("font_size", 26)
	content.add_child(end_battle_title)
	end_battle_body = Label.new()
	end_battle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_battle_body.custom_minimum_size = Vector2(460, 150)
	content.add_child(end_battle_body)
	end_battle_close_button = Button.new()
	end_battle_close_button.text = "Tiếp tục"
	end_battle_close_button.custom_minimum_size = Vector2(0, 42)
	end_battle_close_button.pressed.connect(_close_end_battle_overlay)
	content.add_child(end_battle_close_button)

func _close_end_battle_overlay() -> void:
	if is_instance_valid(end_battle_overlay):
		end_battle_overlay.visible = false

func _show_end_battle_overlay() -> void:
	if not is_instance_valid(end_battle_overlay):
		return
	var victory := outcome == "victory"
	end_battle_title.text = "CHIẾN THẮNG!" if victory else "TRẬN ĐẤU KẾT THÚC · THẤT BẠI"
	end_battle_close_button.text = "Tiếp tục" if victory else "Đóng"
	var summary := "Bạn đã đánh bại toàn bộ kẻ địch."
	if victory:
		summary += "\n\nPhần thưởng:\n" + "\n".join(PackedStringArray(reward_lines))
		summary += "\n\nQuái được thu phục trong trận đã được thêm vào đội hoặc kho."
	else:
		summary = "Đội của bạn bị hạ gục hoặc trận đã vượt quá %d vòng.\n\nBạn có thể bắt đầu trận mới." % max_rounds
	end_battle_body.text = summary
	end_battle_overlay.visible = true

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style

func _new_bar(fill: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#33413c")
	background.set_corner_radius_all(4)
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = fill
	foreground.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", foreground)
	return bar

func _element_color(element: String) -> Color:
	match element:
		"Nature": return Color("#9bc77c")
		"Water": return Color("#74bad5")
		"Fire": return Color("#df805e")
		"Earth": return Color("#bc9b68")
		"Electric": return Color("#e3c76d")
	return Color("#b4aaa1")

func _monster_initial(monster_name: String) -> String:
	return monster_name.substr(0, 1).to_upper()

func _on_speed_changed(_index: int) -> void:
	var speed: int = speed_picker.get_selected_id()
	action_delay = 0.35 / float(speed)

func _on_auto_toggled(enabled: bool) -> void:
	if not enabled or battle_over or action_in_progress:
		return
	if current_actor < 0 or current_actor >= allies.size():
		return
	var actor: Dictionary = allies[current_actor]
	if actor["hp"] <= 0:
		return
	selected_enemy = _first_living_enemy()
	if selected_enemy < 0:
		return
	await _act(_choose_auto_action(actor))

func _on_full_auto_toggled(enabled: bool) -> void:
	if enabled and not auto_toggle.button_pressed:
		auto_toggle.set_pressed_no_signal(true)
		_on_auto_toggled(true)

func _on_contract_selected(index: int) -> void:
	selected_contract = str(contract_picker.get_item_metadata(index))
	_refresh()

func _select_target(index: int) -> void:
	if index < 0 or index >= allies.size() or allies[index]["hp"] <= 0:
		return
	selected_target = index
	_refresh()

func _select_enemy(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	if battle_over or enemies[index]["hp"] <= 0:
		return
	selected_enemy = index
	_refresh()

func _act(action: int) -> void:
	if battle_over or action_in_progress or current_actor < 0 or current_actor >= allies.size():
		return
	var actor: Dictionary = allies[current_actor]
	if actor["hp"] <= 0:
		return
	if selected_enemy < 0 or selected_enemy >= enemies.size() or enemies[selected_enemy]["hp"] <= 0:
		selected_enemy = _first_living_enemy()
	if selected_enemy < 0:
		_finish_if_needed()
		return
	action_in_progress = true
	var used_skill := action > 0 and action < 3
	if action == 0:
		_perform_attack(actor, enemies[selected_enemy], 1.0, false)
		actor["energy"] = mini(100, actor["energy"] + 20)
		_add_log("%s đánh thường vào %s và hồi 20 Energy." % [actor["name"], enemies[selected_enemy]["name"]])
	elif action == 3:
		if not _attempt_capture_in_battle(actor, enemies[selected_enemy]):
			_refresh()
			action_in_progress = false
			return
	else:
		var skill: Dictionary = actor["skills"][action - 1]
		if actor["energy"] < skill["cost"]:
			_add_log("Chưa đủ Energy cho kỹ năng này.")
			_refresh()
			action_in_progress = false
			return
		actor["energy"] -= skill["cost"]
		_perform_skill(actor, skill)

	_resolve_actor_end_turn(current_actor, used_skill)
	turns_taken += 1
	_finish_if_needed()
	_refresh()
	if not battle_over:
		current_actor = -1
		action_in_progress = false
		await _advance_to_next_turn()
	else:
		action_in_progress = false

func _perform_skill(actor: Dictionary, skill: Dictionary) -> void:
	var actor_is_enemy := current_actor >= allies.size()
	var friendly_team: Array = enemies if actor_is_enemy else allies
	var opposing_team: Array = allies if actor_is_enemy else enemies
	var effect: String = str(skill.get("effect", ""))
	var opponent_target_index := -1
	var friendly_target_index := -1
	var target_name := ""
	if effect in ["damage", "damage_bind"]:
		opponent_target_index = _skill_opponent_target(actor, opposing_team)
		if opponent_target_index >= 0:
			target_name = str(opposing_team[opponent_target_index]["name"])
	elif effect == "heal_cleanse":
		friendly_target_index = _skill_friendly_target(actor, friendly_team)
		if friendly_target_index >= 0:
			target_name = str(friendly_team[friendly_target_index]["name"])

	var command := {
		"actor_index": current_actor,
		"skill": skill,
		"opponent_target_index": opponent_target_index,
		"friendly_target_index": friendly_target_index
	}
	if effect in ["damage", "damage_bind"]:
		command["random_multiplier"] = random_source.randf_range(0.95, 1.05)
	var result: Dictionary = BATTLE_SIMULATOR.resolve_skill_command(allies, enemies, command)
	_apply_simulated_team(allies, result["allies"])
	_apply_simulated_team(enemies, result["enemies"])
	var events: Array = result["events"]
	for event in events:
		if event.get("type", "") == "damage_reflected":
			_add_log("Thorny Hide phản %d sát thương bỏ qua DEF." % int(event["amount"]))

	match effect:
		"damage_bind":
			_add_log("%s dùng %s lên %s: gây sát thương và Bind %d lượt." % [actor["name"], skill["name"], target_name, skill["duration"]])
		"team_heal_regen":
			var total_healed := 0
			for event in events:
				if event.get("type", "") == "healed":
					total_healed += int(event.get("amount", 0))
			_add_log("%s dùng %s: hồi %d HP tổng cộng và đặt Regen %d lượt." % [actor["name"], skill["name"], total_healed, skill["duration"]])
		"self_shield_defense":
			var shield_amount := int(events[0].get("amount", 0)) if not events.is_empty() else 0
			_add_log("%s dùng %s: nhận khiên %d và tăng DEF trong %d lượt." % [actor["name"], skill["name"], shield_amount, skill["duration"]])
		"damage":
			var damage := int(events[0].get("hp_damage", 0)) if not events.is_empty() else 0
			_add_log("%s dùng %s lên %s, gây %d sát thương." % [actor["name"], skill["name"], target_name, damage])
		"heal_cleanse":
			var healed_amount := int(events[0].get("amount", 0)) if not events.is_empty() else 0
			var cleanse_result := ""
			for event in events:
				if event.get("type", "") == "effect_removed":
					cleanse_result = str(event.get("effect", ""))
			var cleanse_text := "gỡ hiệu ứng %s" % cleanse_result if not cleanse_result.is_empty() else "không có hiệu ứng xấu để gỡ"
			_add_log("%s dùng %s: hồi %d HP cho %s và %s." % [actor["name"], skill["name"], healed_amount, target_name, cleanse_text])
		"team_shield":
			var total_shield := 0
			for event in events:
				if event.get("type", "") == "shield_created":
					total_shield += int(event.get("amount", 0))
			_add_log("%s dùng %s: tạo %d khiên cho đội trong %d lượt." % [actor["name"], skill["name"], total_shield, skill["duration"]])
		_:
			_add_log("Kỹ năng %s chưa có hiệu ứng xử lý." % skill["name"])

func _apply_simulated_team(current_team: Array, simulated_team: Array) -> void:
	for index in range(mini(current_team.size(), simulated_team.size())):
		var current_unit: Dictionary = current_team[index]
		current_unit.clear()
		current_unit.merge(simulated_team[index], true)

func _perform_attack(attacker: Dictionary, target: Dictionary, multiplier: float, ignore_element: bool, effect_type: String = "", effect_duration: int = 0) -> int:
	var random_multiplier := random_source.randf_range(0.95, 1.05)
	var command := {
		"type": "attack",
		"multiplier": multiplier,
		"ignore_element": ignore_element,
		"effect_type": effect_type,
		"duration": effect_duration
	}
	var result: Dictionary = BATTLE_SIMULATOR.resolve_attack_command(attacker, target, command, random_multiplier)
	var attacker_after: Dictionary = result["attacker"]
	var target_after: Dictionary = result["target"]
	attacker.clear()
	attacker.merge(attacker_after, true)
	target.clear()
	target.merge(target_after, true)
	for event in result["events"]:
		if event.get("type", "") == "damage_reflected":
			_add_log("Thorny Hide phản %d sát thương bỏ qua DEF." % int(event["amount"]))
	return int(result["hp_damage"])

func _effective_stat(unit: Dictionary, stat_name: String) -> float:
	return BATTLE_SIMULATOR.effective_stat(unit, stat_name)

func _has_effect(unit: Dictionary, effect_type: String) -> bool:
	for effect in unit["effects"]:
		if effect["type"] == effect_type:
			return true
	return false

func _skill_opponent_target(actor: Dictionary, team: Array) -> int:
	if current_actor < allies.size():
		return selected_enemy if selected_enemy >= 0 and selected_enemy < team.size() and team[selected_enemy]["hp"] > 0 else _first_living_enemy()
	return BATTLE_SIMULATOR.preferred_target_index(actor, team)

func _skill_friendly_target(_actor: Dictionary, team: Array) -> int:
	if current_actor < allies.size():
		return selected_target if selected_target >= 0 and selected_target < team.size() and team[selected_target]["hp"] > 0 else -1
	return BATTLE_SIMULATOR.heal_target_index(team, 0.5)

func _choose_enemy_skill(actor: Dictionary) -> int:
	return BATTLE_SIMULATOR.choose_enemy_skill(actor, enemies, allies)

func _resolve_actor_end_turn(actor_index: int, used_skill: bool, trigger_passives: bool = true) -> void:
	var result: Dictionary = BATTLE_SIMULATOR.resolve_end_turn_command(allies, enemies, actor_index, used_skill, trigger_passives)
	_apply_simulated_team(allies, result["allies"])
	_apply_simulated_team(enemies, result["enemies"])
	for event in result["events"]:
		var target_name := str(event.get("target_name", "quái thú"))
		match event.get("type", ""):
			"passive_heal":
				if event.get("passive", "") == "tidal_rhythm":
					_add_log("Tidal Rhythm hồi thêm %d HP cho %s." % [int(event.get("amount", 0)), target_name])
				elif event.get("passive", "") == "forest_vitality":
					_add_log("Forest Vitality hồi %d HP cho %s." % [int(event.get("amount", 0)), target_name])
			"burn_damage":
				_add_log("%s chịu %d sát thương Burn." % [target_name, int(event.get("amount", 0))])
			"regen_heal":
				_add_log("Regen hồi %d HP cho %s." % [int(event.get("amount", 0)), target_name])
			"effect_expired":
				_add_log("Hiệu ứng %s trên %s kết thúc." % [str(event.get("effect", "")), target_name])

func _is_capture_candidate(target: Dictionary) -> bool:
	return int(target.get("hp", 0)) > 0 and bool(target.get("capturable", false)) and CAPTURE_BASE.has(str(target.get("rarity", ""))) and not bool(target.get("captured", false))

func _capture_chance(target: Dictionary) -> float:
	if not _is_capture_candidate(target):
		return 0.0
	var max_hp := maxi(1, int(target.get("max_hp", 1)))
	var hp_ratio := clampf(float(target.get("hp", 0)) / float(max_hp), 0.0, 1.0)
	return clampf(float(CAPTURE_BASE[str(target["rarity"])]) * (1.6 - hp_ratio) * float(CONTRACT_MULTIPLIER.get(selected_contract, 1.0)) + capture_pity, 0.05, 0.9)

func _attempt_capture_in_battle(actor: Dictionary, target: Dictionary) -> bool:
	if not _is_capture_candidate(target):
		_add_log("Chỉ có thể thu phục địch còn sống và có thể thu phục.")
		return false
	var inventory: Dictionary = player_profile.get("inventory", {})
	var contract_id := "monster_contract_%s" % selected_contract.to_lower()
	var contract_count := int(inventory.get(contract_id, 0))
	if contract_count <= 0:
		_add_log("Bạn không còn %s." % _contract_display_name(selected_contract))
		return false

	var chance := _capture_chance(target)
	inventory[contract_id] = contract_count - 1
	player_profile["inventory"] = inventory
	if random_source.randf() < chance:
		var captured_entry := {
			"instance_id": "creature_%d_%d" % [int(Time.get_unix_time_from_system()), random_source.randi_range(1000, 999999)],
			"monster_id": target["id"],
			"star_rank": target["star_rank"],
			"training_exp": 0,
			"nickname": ""
		}
		var team: Array = player_profile.get("team", [])
		var team_limit := int(_resource_value(selected_encounter, &"max_allies", 3))
		if team.size() < team_limit:
			team.append(captured_entry)
		else:
			var storage: Array = player_profile.get("storage", [])
			storage.append(captured_entry)
			player_profile["storage"] = storage
		player_profile["team"] = team
		target["captured"] = true
		target["hp"] = 0
		capture_pity = 0.0
		_add_log("%s dùng %s và thu phục thành công %s (%.0f%%)." % [actor["name"], _contract_display_name(selected_contract), target["name"], chance * 100.0])
	else:
		capture_pity += 0.05
		_add_log("%s dùng %s nhưng thu phục %s thất bại (%.0f%%). Địch vẫn chiến đấu; lần sau +5%%." % [actor["name"], _contract_display_name(selected_contract), target["name"], chance * 100.0])
	PLAYER_SAVE.save(player_profile)
	return true

func _contract_display_name(contract_type: String) -> String:
	match contract_type:
		"Advanced": return "Hợp đồng Nâng cao"
		"Master": return "Hợp đồng Bậc thầy"
	return "Hợp đồng Cơ bản"

func _advance_to_next_turn() -> void:
	while not battle_over:
		if turns_taken >= max_rounds * (allies.size() + enemies.size()):
			_finish_battle("defeat")
			return
		if _living_ally_count() == 0:
			_finish_battle("defeat")
			return
		if _living_enemy_count() == 0:
			_finish_if_needed()
			return
		var next_actor := _choose_next_actor()
		if next_actor >= allies.size():
			var enemy_index := next_actor - allies.size()
			current_actor = next_actor
			acting_enemy_index = enemy_index
			var enemy_unit: Dictionary = enemies[enemy_index]
			_add_log("%s bước vào lượt hành động." % enemy_unit["name"])
			_refresh()
			await get_tree().create_timer(action_delay).timeout
			if battle_over or enemy_unit["hp"] <= 0:
				acting_enemy_index = -1
				return
			if _has_effect(enemy_unit, "stun"):
				_add_log("%s bị Stun và mất lượt." % enemy_unit["name"])
				_resolve_actor_end_turn(current_actor, false, false)
			else:
				var skill_index := _choose_enemy_skill(enemy_unit)
				if skill_index >= 0:
					var skill: Dictionary = enemy_unit["skills"][skill_index]
					enemy_unit["energy"] -= skill["cost"]
					_perform_skill(enemy_unit, skill)
				else:
					_enemy_attack(enemy_index)
					enemy_unit["energy"] = mini(100, enemy_unit["energy"] + 20)
				_resolve_actor_end_turn(current_actor, skill_index >= 0)
			turns_taken += 1
			acting_enemy_index = -1
			_finish_if_needed()
			if battle_over:
				return
			if turns_taken >= max_rounds * (allies.size() + enemies.size()) and not battle_over:
				_finish_battle("defeat")
				return
			_refresh()
		else:
			current_actor = next_actor
			selected_target = current_actor
			if selected_enemy < 0 or selected_enemy >= enemies.size() or enemies[selected_enemy]["hp"] <= 0:
				selected_enemy = _first_living_enemy()
			var actor: Dictionary = allies[current_actor]
			if _has_effect(actor, "stun"):
				_add_log("%s bị Stun và mất lượt." % actor["name"])
				_resolve_actor_end_turn(current_actor, false, false)
				turns_taken += 1
				continue
			_add_log("%s tới lượt (SPD %.0f)." % [actor["name"], _effective_stat(actor, "spd")])
			_refresh()
			if auto_toggle.button_pressed:
				var auto_actor_index := current_actor
				var turns_before_auto := turns_taken
				await get_tree().create_timer(action_delay).timeout
				if battle_over or not auto_toggle.button_pressed or current_actor != auto_actor_index or turns_taken != turns_before_auto:
					return
				selected_enemy = _first_living_enemy()
				await _act(_choose_auto_action(actor))
			return

func _choose_next_actor() -> int:
	while true:
		var result: Dictionary = BATTLE_SIMULATOR.advance_action_gauges(allies, enemies, gauges)
		gauges.assign(result.get("gauges", []))
		var chosen := int(result.get("actor_index", -1))
		if chosen >= 0:
			return chosen
	return -1

func _enemy_attack(enemy_index: int) -> void:
	var enemy_unit: Dictionary = enemies[enemy_index]
	var target_index := BATTLE_SIMULATOR.preferred_target_index(enemy_unit, allies)
	if target_index < 0:
		return
	var target: Dictionary = allies[target_index]
	var damage := _perform_attack(enemy_unit, target, 1.0, false)
	_add_log("%s tấn công %s, gây %d HP sát thương." % [enemy_unit["name"], target["name"], damage])

func _choose_auto_action(actor: Dictionary) -> int:
	return BATTLE_SIMULATOR.choose_auto_action(actor, full_auto_toggle.button_pressed)

func _finish_if_needed() -> void:
	if _living_enemy_count() == 0:
		_finish_battle("victory")
	elif _living_ally_count() == 0:
		_finish_battle("defeat")

func _finish_battle(result: String) -> void:
	battle_over = true
	outcome = result
	current_actor = -1
	acting_enemy_index = -1
	action_in_progress = false
	if is_instance_valid(auto_toggle):
		auto_toggle.set_pressed_no_signal(false)
		auto_toggle.disabled = true
	if is_instance_valid(full_auto_toggle):
		full_auto_toggle.set_pressed_no_signal(false)
		full_auto_toggle.disabled = true
	if result in ["victory", "captured"]:
		_award_victory_rewards()
		_add_log("CHIẾN THẮNG! %s" % ", ".join(PackedStringArray(reward_lines)))
	else:
		_add_log("THẤT BẠI. Đội đã bị hạ gục hoặc trận vượt quá %d vòng." % max_rounds)
	_refresh()
	_show_end_battle_overlay()

func _award_victory_rewards() -> void:
	if rewards_claimed:
		return
	rewards_claimed = true
	var team: Array = player_profile.get("team", [])
	var inventory: Dictionary = player_profile.get("inventory", {})
	var dropped_any := false
	for ally_index in range(allies.size()):
		var exp_amount := 0
		for defeated in enemies:
			if not defeated["captured"]:
				exp_amount += int(defeated["exp_reward"]) if allies[ally_index]["hp"] > 0 else roundi(float(defeated["exp_reward"]) * 0.5)
		allies[ally_index]["training_exp"] += exp_amount
		if ally_index < team.size():
			team[ally_index]["training_exp"] = int(team[ally_index].get("training_exp", 0)) + exp_amount
		reward_lines.append("%s +%d EXP huấn luyện" % [allies[ally_index]["name"], exp_amount])
	for defeated in enemies:
		if defeated["captured"]:
			continue
		for drop in defeated["loot_table"]:
			if random_source.randf() <= drop["chance"]:
				var quantity: int = random_source.randi_range(drop["min"], drop["max"])
				reward_lines.append("%s x%d" % [drop["item"], quantity])
				var item_id: String = str(drop.get("item_id", "unknown"))
				inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
				dropped_any = true
	if not dropped_any:
		reward_lines.append("không rơi vật phẩm")
	player_profile["team"] = team
	player_profile["inventory"] = inventory
	PLAYER_SAVE.save(player_profile)

func _living_enemy_count() -> int:
	var count := 0
	for enemy_unit in enemies:
		if enemy_unit["hp"] > 0:
			count += 1
	return count

func _first_living_enemy() -> int:
	for index in range(enemies.size()):
		if enemies[index]["hp"] > 0:
			return index
	return -1

func _living_ally_count() -> int:
	var count := 0
	for ally in allies:
		if ally["hp"] > 0:
			count += 1
	return count

func _add_log(message: String) -> void:
	log_label.append_text(message + "\n")
	log_label.scroll_to_line(log_label.get_line_count())

func _refresh() -> void:
	if not is_instance_valid(log_label):
		return
	auto_toggle.disabled = battle_over
	full_auto_toggle.disabled = battle_over
	contract_picker.disabled = battle_over or action_in_progress
	var contract_ids := ["monster_contract_basic", "monster_contract_advanced", "monster_contract_master"]
	var contract_index: int = {"Basic": 0, "Advanced": 1, "Master": 2}.get(selected_contract, 0)
	var inventory: Dictionary = player_profile.get("inventory", {})
	contract_picker.set_item_text(0, "Cơ bản · %d" % int(inventory.get(contract_ids[0], 0)))
	contract_picker.set_item_text(1, "Nâng cao · %d" % int(inventory.get(contract_ids[1], 0)))
	contract_picker.set_item_text(2, "Bậc thầy · %d" % int(inventory.get(contract_ids[2], 0)))
	contract_picker.select(contract_index)
	var round_number := mini(floori(float(turns_taken) / float(maxi(1, allies.size() + enemies.size()))) + 1, max_rounds)
	round_label.text = "VÒNG %d / %d" % [round_number, max_rounds]
	if battle_over:
		turn_status_label.text = "TRẬN ĐẤU ĐÃ KẾT THÚC  ·  %s" % ("CHIẾN THẮNG" if outcome == "victory" else "THẤT BẠI")
	elif acting_enemy_index >= 0:
		turn_status_label.text = "%s ĐANG HÀNH ĐỘNG" % enemies[acting_enemy_index]["name"].to_upper()
	elif current_actor >= 0 and current_actor < allies.size():
		turn_status_label.text = "ĐẾN LƯỢT %s  ·  Chọn mục tiêu địch rồi chọn kỹ năng" % allies[current_actor]["name"].to_upper()
	else:
		turn_status_label.text = "ĐANG TÍNH LƯỢT TIẾP THEO"
	turn_queue_label.text = _turn_queue_text()
	for index in range(allies.size()):
		var ally: Dictionary = allies[index]
		var target_marker: String = "MỤC TIÊU HỒI MÁU" if index == selected_target else ally["role"]
		var actor_marker: String = "▶ " if index == current_actor else ""
		ally_buttons[index].text = "%s%s  ·  %s" % [actor_marker, ally["name"], ally["element"]]
		ally_buttons[index].disabled = ally["hp"] <= 0
		ally_detail_labels[index].text = "%s   HP %d/%d   EN %d/100   Khiên %d" % [target_marker, ally["hp"], ally["max_hp"], ally["energy"], ally["shield"]]
		ally_hp_bars[index].max_value = ally["max_hp"]
		ally_hp_bars[index].value = ally["hp"]
		ally_energy_bars[index].value = ally["energy"]
		ally_gauge_bars[index].value = gauges[index]
		var passive_text := str(ally.get("passive_name", ""))
		ally_effect_labels[index].text = "Nội tại · %s   |   %s" % [passive_text, _effects_text(ally)]
		var border_color := Color("#e4bd68") if index == current_actor else Color("#66b5ca") if index == selected_target else Color("#385247")
		ally_cards[index].add_theme_stylebox_override("panel", _panel_style(Color("#26332f"), border_color))

	if selected_enemy < 0 or selected_enemy >= enemies.size() or enemies[selected_enemy]["hp"] <= 0:
		selected_enemy = _first_living_enemy()
	for index in range(enemies.size()):
		var enemy_unit: Dictionary = enemies[index]
		var enemy_actor_index := allies.size() + index
		var target_marker := "◀ MỤC TIÊU" if index == selected_enemy and enemy_unit["hp"] > 0 else ""
		var actor_marker := "▶ " if enemy_actor_index == current_actor or index == acting_enemy_index else ""
		enemy_target_buttons[index].text = "%s%s%s" % [actor_marker, enemy_unit["name"], target_marker]
		enemy_target_buttons[index].disabled = enemy_unit["hp"] <= 0 or battle_over
		enemy_detail_labels[index].text = "%s   %s · %s   HP %d/%d" % [enemy_unit["role"], enemy_unit["element"], enemy_unit["rarity"], enemy_unit["hp"], enemy_unit["max_hp"]]
		enemy_hp_bars[index].max_value = enemy_unit["max_hp"]
		enemy_hp_bars[index].value = enemy_unit["hp"]
		enemy_gauge_bars[index].value = gauges[enemy_actor_index]
		var capture_text := "Không thể thu phục"
		if _is_capture_candidate(enemy_unit):
			capture_text = "Thu phục: %.0f%%" % (_capture_chance(enemy_unit) * 100.0)
		enemy_effect_labels[index].text = "%s   |   %s" % [_effects_text(enemy_unit), capture_text]
		var enemy_border := Color("#e4bd68") if index == acting_enemy_index else Color("#df9a6e") if index == selected_enemy else Color("#865544")
		enemy_cards[index].add_theme_stylebox_override("panel", _panel_style(Color("#302522") if enemy_unit["hp"] > 0 else Color("#20201f"), enemy_border))

	for index in range(action_buttons.size()):
		action_buttons[index].disabled = battle_over or current_actor < 0 or current_actor >= allies.size()
		action_buttons[index].visible = true
	if current_actor >= 0 and current_actor < allies.size():
		var skills: Array = allies[current_actor].get("skills", [])
		if skills.size() > 0:
			action_buttons[1].text = "%s · %d" % [skills[0]["name"], skills[0]["cost"]]
			action_buttons[1].disabled = battle_over or allies[current_actor]["energy"] < skills[0]["cost"]
			action_buttons[1].tooltip_text = skills[0].get("description", "")
		if skills.size() > 1:
			action_buttons[2].text = "%s · %d" % [skills[1]["name"], skills[1]["cost"]]
			action_buttons[2].disabled = battle_over or allies[current_actor]["energy"] < skills[1]["cost"]
			action_buttons[2].tooltip_text = skills[1].get("description", "")
	if action_buttons.size() > 3 and action_buttons[3].visible:
		var selected_contract_index: int = {"Basic": 0, "Advanced": 1, "Master": 2}.get(selected_contract, 0)
		var contract_id: String = contract_ids[selected_contract_index]
		var has_capture_attempt: bool = int(inventory.get(contract_id, 0)) > 0
		var valid_capture_selection: bool = selected_enemy >= 0 and selected_enemy < enemies.size() and _is_capture_candidate(enemies[selected_enemy])
		action_buttons[3].disabled = battle_over or current_actor < 0 or current_actor >= allies.size() or not has_capture_attempt or not valid_capture_selection
		if has_capture_attempt and valid_capture_selection:
			action_buttons[3].text = "Thu phục · %.0f%%" % (_capture_chance(enemies[selected_enemy]) * 100.0)
		else:
			action_buttons[3].text = "Thu phục · thiếu hợp đồng" if not has_capture_attempt else "Chọn địch có thể thu phục"
		action_buttons[3].tooltip_text = "Thu phục tiêu hao một Monster Contract và lượt hành động của quái đang tới lượt."
	restart_button.visible = battle_over

func _turn_queue_text() -> String:
	if battle_over:
		return ""
	var entries: Array[Dictionary] = []
	for index in range(allies.size() + enemies.size()):
		var unit := _combatant_at(index)
		if unit["hp"] <= 0:
			continue
		var eta := 0 if index == current_actor else ceili(float(maxi(0, 1000 - gauges[index])) / _effective_stat(unit, "spd"))
		entries.append({"id": index, "eta": eta, "name": unit["name"]})
	for first in range(entries.size()):
		for second in range(first + 1, entries.size()):
			var left: Dictionary = entries[first]
			var right: Dictionary = entries[second]
			if right["eta"] < left["eta"] or right["eta"] == left["eta"] and right["id"] < left["id"]:
				entries[first] = right
				entries[second] = left
	var names: Array[String] = []
	for entry in entries:
		names.append(str(entry["name"]))
	return "THỨ TỰ DỰ KIẾN  →  " + "  →  ".join(PackedStringArray(names))

func _combatant_at(index: int) -> Dictionary:
	if index < allies.size():
		return allies[index]
	return enemies[index - allies.size()]

func _effects_text(unit: Dictionary) -> String:
	if unit["effects"].is_empty():
		return "Không có hiệu ứng"
	var labels: Array[String] = []
	for effect in unit["effects"]:
		var label := str(effect["type"])
		match effect["type"]:
			"atk_up": label = "ATK+"
			"atk_down": label = "ATK−"
			"def_up": label = "DEF+"
			"def_down": label = "DEF−"
			"bind": label = "Bind"
			"burn": label = "Burn"
			"regen": label = "Regen"
			"stun": label = "Stun"
			"shield": label = "Shield"
		labels.append("%s(%d)" % [label, effect["turns"]])
	return ", ".join(PackedStringArray(labels))
