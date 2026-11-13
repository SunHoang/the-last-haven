extends Control

const PLAYER_SAVE = preload("res://scripts/data/player_save.gd")
const DEFAULT_ROSTER = preload("res://data/player/default_roster.tres")
const MONSTER_CATALOG = preload("res://data/monsters/catalog.tres")
const TRAINING_PROGRESSION = preload("res://data/training_progression.tres")
const MAX_FARM_WORKERS := 2
const MAX_LUMBER_WORKERS := 2

const BUILDINGS: Array[Dictionary] = [
	{
		"id": "exploration",
		"name": "Trạm Khám Phá (Active DAG)",
		"icon": "🧭",
		"summary": "Thám hiểm chủ động bản đồ DAG 7 tầng, tiêu hao Supply.",
		"details": "Active Exploration: Di chuyển qua bản đồ nhánh DAG (7 tầng từ Start đến Boss). Mỗi bước tốn 1 Supply (Tối đa 10 Supply). Hết Supply tự động rút lui an toàn và giữ toàn bộ chiến lợi phẩm."
	},
	{
		"id": "dungeon",
		"name": "Cổng Thử Thách",
		"icon": "⚔",
		"summary": "Chọn trận thường, tinh anh hoặc Boss.",
		"details": "Các trận hiện có được mở từ Cổng Thử Thách. Về sau nơi này sẽ quản lý độ khó, điều kiện mở khóa vùng và phần thưởng đánh Boss.",
		"scene": "res://scenes/battle/Battle.tscn"
	},
	{
		"id": "farm",
		"name": "Nông Trại",
		"icon": "🌱",
		"summary": "Trồng trọt và thu hoạch lương thực, thảo dược.",
		"details": "Nông Trại sản xuất thức ăn, thảo dược và sợi theo thời gian. Quái có nghề phù hợp sẽ tăng sản lượng khi được phân công."
	},
	{
		"id": "lumber_mill",
		"name": "Xưởng Gỗ",
		"icon": "🪵",
		"summary": "Giao quái thu thập gỗ và vật liệu rừng.",
		"details": "Xưởng Gỗ tạo gỗ theo thời gian. Quái có nghề phù hợp sẽ tăng hiệu suất khi được giao việc."
	},
	{
		"id": "training",
		"name": "Sân Huấn Luyện",
		"icon": "🎯",
		"summary": "Theo dõi EXP và phát triển cấp sao.",
		"details": "Dùng EXP huấn luyện nhận được từ trận đấu để tăng hạng sao cho từng cá thể. Hạng sao mới sẽ tăng chỉ số trong các trận tiếp theo."
	},
	{
		"id": "expedition",
		"name": "Bến Viễn Chinh (Passive)",
		"icon": "🛶",
		"summary": "Gửi một đội đi kiếm tài nguyên treo máy khi bạn vắng mặt.",
		"details": "Passive Expedition lưu giờ bắt đầu, thời lượng và đội được giao trong game_state. Khi quay lại, bạn nhận tài nguyên theo vùng và chuyên môn của quái."
	}
]

var page_root: Control
var building_grid: GridContainer
var player_profile: Dictionary = {}
var farm_pending_label: Label
var farm_resources_label: Label
var farm_status_label: Label
var farm_worker_checks: Array[CheckBox] = []
var farm_notice := ""
var lumber_pending_label: Label
var lumber_stock_label: Label
var lumber_status_label: Label
var lumber_notice := ""
var production_timer: Timer
var active_production_building := ""
var last_production_autosave_unix := 0
var expedition_timer: Timer
var expedition_status_label: Label
var expedition_selection_label: Label
var expedition_region_picker: OptionButton
var expedition_duration_picker: OptionButton
var expedition_member_checks: Array[CheckBox] = []
var expedition_notice := ""

func _ready() -> void:
	player_profile = PLAYER_SAVE.load_or_create(DEFAULT_ROSTER)
	_resolve_expedition_if_ready()
	expedition_timer = Timer.new()
	expedition_timer.wait_time = 1.0
	expedition_timer.timeout.connect(_on_expedition_timer_timeout)
	add_child(expedition_timer)
	expedition_timer.start()
	_show_base()

func _show_base() -> void:
	_clear_page()
	var layout := _make_page("THE LAST HAVEN", "CĂN CỨ")
	var subtitle := Label.new()
	subtitle.text = "Chọn một công trình để vào bên trong."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)
	var resources := Label.new()
	var inventory: Dictionary = player_profile.get("resources", {})
	resources.text = "Tài nguyên  ·  Thức ăn %d     Thảo dược %d     Sợi %d     Gỗ %d" % [
		int(inventory.get("food", 0)),
		int(inventory.get("herbs", 0)),
		int(inventory.get("fiber", 0)),
		int(inventory.get("wood", 0))
	]
	resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resources.add_theme_color_override("font_color", Color("#b8c9c2"))
	layout.add_child(resources)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	building_grid = GridContainer.new()
	building_grid.columns = 2
	building_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_grid.add_theme_constant_override("h_separation", 12)
	building_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(building_grid)
	for building in BUILDINGS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%s" % [str(building["icon"]), str(building["name"])]
		button.pressed.connect(_open_building.bind(building))
		building_grid.add_child(button)

func _open_building(building: Dictionary) -> void:
	var scene_path := str(building.get("scene", ""))
	if not scene_path.is_empty():
		get_tree().change_scene_to_file(scene_path)
		return
	var bldg_id: String = str(building.get("id", ""))
	if bldg_id == "exploration":
		_show_active_exploration()
		return
	if bldg_id == "farm":
		_show_farm()
		return
	if bldg_id == "lumber_mill":
		_show_lumber_mill()
		return
	if bldg_id == "training":
		_show_training()
		return
	if bldg_id == "expedition":
		_show_expedition()
		return
	_clear_page()
	var layout := _make_page(str(building["name"]), "CÔNG TRÌNH CĂN CỨ", true)
	var icon := Label.new()
	icon.text = str(building["icon"])
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 58)
	layout.add_child(icon)
	var description := Label.new()
	description.text = str(building["details"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size = Vector2(0, 90)
	layout.add_child(description)
	var state := Label.new()
	state.text = "Công trình đã có khu vực riêng. Chức năng sẽ được xây tiếp tại đây."
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_color_override("font_color", Color("#e4bd78"))
	layout.add_child(state)

func _show_active_exploration() -> void:
	_clear_page()
	var layout := _make_page("TRẠM KHÁM PHÁ", "ACTIVE EXPLORATION (BẢN ĐỒ DAG)", true)
	var exploration: Dictionary = player_profile.get("exploration", PLAYER_SAVE.create_default_active_exploration())
	var is_active: bool = bool(exploration.get("active", false))
	var region_name: String = str(exploration.get("region_name", "Rừng Cổ Đại"))
	var current_layer: int = int(exploration.get("current_layer", 0))
	var total_layers: int = int(exploration.get("total_layers", 7))
	var supply: int = int(exploration.get("supply", 10))
	var max_supply: int = int(exploration.get("max_supply", 10))

	var info := Label.new()
	info.text = "Bản đồ nhánh DAG %d tầng (Layer 0: Start → Layer %d: Boss).\nMỗi bước di chuyển tiêu hao 1 Supply. Về 0 Supply sẽ tự động rút lui an toàn và giữ 100%% chiến lợi phẩm." % [total_layers, total_layers - 1]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(info)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#e4bd78"))
	if is_active:
		status_label.text = "Đang khám phá: %s  ·  Tầng %d / %d  ·  Supply: %d / %d" % [
			region_name,
			current_layer,
			total_layers - 1,
			supply,
			max_supply
		]
	else:
		status_label.text = "Trạng thái: Chưa xuất phát  ·  Supply chuẩn bị: %d / %d" % [max_supply, max_supply]
	layout.add_child(status_label)

func _show_expedition() -> void:
	_clear_page()
	_resolve_expedition_if_ready()
	expedition_notice = ""
	expedition_member_checks.clear()
	var layout := _make_page("BẾN VIỄN CHINH", "PASSIVE EXPEDITION (TREO MÁY)", true)
	var intro := Label.new()
	intro.text = "Cử từ 1 đến 3 quái đi thu thập tài nguyên thụ động. Chuyến đi tiếp tục khi bạn rời game."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(intro)
	var active: Dictionary = player_profile.get("expedition", {})
	if bool(active.get("active", false)):
		var active_region_id: String = str(active.get("region_id", ""))
		var region_dict: Dictionary = PLAYER_SAVE.find_expedition_region(player_profile, active_region_id)
		var region_name: String = str(region_dict.get("display_name", str(active.get("region_name", "Vùng không xác định"))))
		var squad_names: Array[String] = []
		var active_squad_ids: Array = active.get("squad_ids", [])
		for instance_id_var: Variant in active_squad_ids:
			var instance_id: String = str(instance_id_var)
			var creature: Dictionary = _find_owned_creature(instance_id)
			var species_key: String = str(creature.get("def_id", creature.get("monster_id", "")))
			var definition: Resource = MONSTER_CATALOG.find_monster(species_key)
			var display_name: String = str(definition.get("display_name")) if definition != null else species_key
			squad_names.append(display_name if not display_name.is_empty() else "Quái thú")
		var squad_label := Label.new()
		squad_label.text = "ĐỘI ĐANG ĐI  ·  " + "  ·  ".join(squad_names)
		squad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		squad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(squad_label)
		expedition_status_label = Label.new()
		expedition_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		expedition_status_label.add_theme_font_size_override("font_size", 22)
		layout.add_child(expedition_status_label)
		_refresh_expedition_status(region_name)
		return
	var last_result: String = str(player_profile.get("last_expedition_result", ""))
	if not last_result.is_empty():
		var result_label := Label.new()
		result_label.text = last_result
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_label.add_theme_color_override("font_color", Color("#e4bd78"))
		layout.add_child(result_label)
	var selectors := HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 8)
	layout.add_child(selectors)
	var region_column := VBoxContainer.new()
	region_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(region_column)
	var region_heading := Label.new()
	region_heading.text = "VÙNG"
	region_column.add_child(region_heading)
	expedition_region_picker = OptionButton.new()
	expedition_region_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var regions: Array = PLAYER_SAVE.get_expedition_regions(player_profile)
	for index: int in range(regions.size()):
		var region_entry: Variant = regions[index]
		if typeof(region_entry) != TYPE_DICTIONARY:
			continue
		var region_info: Dictionary = region_entry
		var r_name: String = str(region_info.get("display_name", "Vùng %d" % (index + 1)))
		var r_id: String = str(region_info.get("region_id", ""))
		expedition_region_picker.add_item(r_name)
		expedition_region_picker.set_item_metadata(index, r_id)
	region_column.add_child(expedition_region_picker)
	var duration_column := VBoxContainer.new()
	duration_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(duration_column)
	var duration_heading := Label.new()
	duration_heading.text = "THỜI LƯỢNG"
	duration_column.add_child(duration_heading)
	expedition_duration_picker = OptionButton.new()
	expedition_duration_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_column.add_child(expedition_duration_picker)
	expedition_region_picker.item_selected.connect(_refresh_expedition_durations)
	if expedition_region_picker.item_count > 0:
		expedition_region_picker.select(0)
		_refresh_expedition_durations(0)
	var squad_heading := Label.new()
	squad_heading.text = "CHỌN ĐỘI  ·  TỐI ĐA 3 QUÁI"
	squad_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(squad_heading)
	var squad_scroll := ScrollContainer.new()
	squad_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(squad_scroll)
	var squad_list := VBoxContainer.new()
	squad_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_list.add_theme_constant_override("separation", 4)
	squad_scroll.add_child(squad_list)
	var owned: Array[Dictionary] = _get_owned_creatures()
	var working_ids: Dictionary = _assigned_worker_ids()
	var busy_ids: Dictionary = _busy_expedition_ids()
	for creature: Dictionary in owned:
		var species_key: String = str(creature.get("def_id", creature.get("monster_id", "")))
		var instance_id: String = str(creature.get("instance_id", species_key))
		var definition: Resource = MONSTER_CATALOG.find_monster(species_key)
		var monster_name: String = str(definition.get("display_name")) if definition != null else species_key
		var profession: String = str(definition.get("profession")) if definition != null else ""
		var check := CheckBox.new()
		var prof_suffix: String = ("  ·  " + profession) if not profession.is_empty() else ""
		check.text = "%s%s" % [monster_name, prof_suffix]
		check.set_meta("instance_id", instance_id)
		check.disabled = working_ids.has(instance_id) or busy_ids.has(instance_id)
		if working_ids.has(instance_id):
			check.tooltip_text = "Quái đang làm việc; hãy bỏ phân công trước khi gửi đi."
		elif busy_ids.has(instance_id):
			check.tooltip_text = "Quái đang ở một chuyến viễn chinh khác."
		check.toggled.connect(_on_expedition_member_toggled.bind(instance_id, check))
		squad_list.add_child(check)
		expedition_member_checks.append(check)
	expedition_selection_label = Label.new()
	expedition_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(expedition_selection_label)
	var start_button := Button.new()
	start_button.text = "Bắt đầu Viễn Chinh"
	start_button.custom_minimum_size = Vector2(0, 44)
	start_button.pressed.connect(_start_expedition)
	layout.add_child(start_button)
	_update_expedition_selection_label()

func _refresh_expedition_durations(region_index: int) -> void:
	if not is_instance_valid(expedition_duration_picker) or region_index < 0:
		return
	expedition_duration_picker.clear()
	var region_id: String = str(expedition_region_picker.get_item_metadata(region_index))
	var region_dict: Dictionary = PLAYER_SAVE.find_expedition_region(player_profile, region_id)
	if region_dict.is_empty():
		return
	var durations: Array = region_dict.get("durations_minutes", [15, 30, 120])
	for minutes_var: Variant in durations:
		var minutes_val: int = int(minutes_var)
		expedition_duration_picker.add_item("%d phút" % minutes_val, minutes_val)
	if expedition_duration_picker.item_count > 0:
		expedition_duration_picker.select(0)

func _on_expedition_member_toggled(pressed: bool, _instance_id: String, check: CheckBox) -> void:
	if pressed:
		var selected_count := 0
		for member_check in expedition_member_checks:
			if member_check.button_pressed:
				selected_count += 1
		if selected_count > 3:
			check.set_pressed_no_signal(false)
			expedition_notice = "Một chuyến chỉ nhận tối đa 3 quái."
		else:
			expedition_notice = ""
	_update_expedition_selection_label()

func _update_expedition_selection_label() -> void:
	if not is_instance_valid(expedition_selection_label):
		return
	var selected_count := 0
	for check in expedition_member_checks:
		if check.button_pressed:
			selected_count += 1
	expedition_selection_label.text = expedition_notice if not expedition_notice.is_empty() else "Đội: %d / 3 quái được chọn." % selected_count

func _start_expedition() -> void:
	var squad_ids: Array[String] = []
	for check in expedition_member_checks:
		if check.button_pressed:
			squad_ids.append(str(check.get_meta("instance_id", "")))
	if squad_ids.is_empty() or squad_ids.size() > 3:
		expedition_notice = "Hãy chọn từ 1 đến 3 quái."
		_update_expedition_selection_label()
		return
	if expedition_region_picker.selected < 0 or expedition_duration_picker.selected < 0:
		return
	var region_id: String = str(expedition_region_picker.get_item_metadata(expedition_region_picker.selected))
	var region_dict: Dictionary = PLAYER_SAVE.find_expedition_region(player_profile, region_id)
	var region_name: String = str(region_dict.get("display_name", "Rừng Cổ Đại"))
	var duration_minutes: int = expedition_duration_picker.get_selected_id()
	var now: int = int(Time.get_unix_time_from_system())
	var current_expedition: Dictionary = player_profile.get("expedition", PLAYER_SAVE.create_default_passive_expedition())
	current_expedition["active"] = true
	current_expedition["region_id"] = region_id
	current_expedition["region_name"] = region_name
	current_expedition["squad_ids"] = squad_ids
	current_expedition["start_unix"] = now
	current_expedition["duration_seconds"] = duration_minutes * 60
	player_profile["expedition"] = current_expedition
	player_profile["last_expedition_result"] = ""
	PLAYER_SAVE.save(player_profile)
	_show_expedition()

func _on_expedition_timer_timeout() -> void:
	if _resolve_expedition_if_ready():
		if is_instance_valid(expedition_status_label):
			_show_expedition()
		return
	if is_instance_valid(expedition_status_label):
		var active: Dictionary = player_profile.get("expedition", {})
		var active_region_id: String = str(active.get("region_id", ""))
		var region_dict: Dictionary = PLAYER_SAVE.find_expedition_region(player_profile, active_region_id)
		var region_name: String = str(region_dict.get("display_name", str(active.get("region_name", active_region_id))))
		_refresh_expedition_status(region_name)

func _refresh_expedition_status(region_name: String) -> void:
	if not is_instance_valid(expedition_status_label):
		return
	var active: Dictionary = player_profile.get("expedition", {})
	var end_time: int = int(active.get("start_unix", 0)) + int(active.get("duration_seconds", 0))
	var remaining: int = maxi(0, end_time - int(Time.get_unix_time_from_system()))
	if remaining <= 0:
		expedition_status_label.text = "%s · Đang trở về..." % region_name
	else:
		expedition_status_label.text = "%s\nThời gian còn lại: %s" % [region_name, _format_expedition_time(remaining)]

func _format_expedition_time(seconds: int) -> String:
	var hours := floori(float(seconds) / 3600.0)
	var minutes := floori(float(seconds % 3600) / 60.0)
	var remaining_seconds := seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, remaining_seconds]

func _resolve_expedition_if_ready() -> bool:
	var active: Dictionary = player_profile.get("expedition", {})
	if not bool(active.get("active", false)):
		return false
	var end_time: int = int(active.get("start_unix", 0)) + int(active.get("duration_seconds", 0))
	if int(Time.get_unix_time_from_system()) < end_time:
		return false
	var active_region_id: String = str(active.get("region_id", ""))
	var region_dict: Dictionary = PLAYER_SAVE.find_expedition_region(player_profile, active_region_id)
	var save_helper := PLAYER_SAVE.new(player_profile)
	var resources: Dictionary = player_profile.get("resources", {})
	var total_rewards: Dictionary = {}
	var total_exp: int = 0
	if not region_dict.is_empty():
		var duration_scale: float = float(active.get("duration_seconds", 0)) / 1800.0
		var base_rewards: Dictionary = region_dict.get("base_rewards_per_30_minutes", {})
		var preferred_prof: String = str(region_dict.get("preferred_profession", ""))
		var spec_bonus: float = float(region_dict.get("specialization_bonus_percent", 0))
		var exp_per_30m: float = float(region_dict.get("training_exp_per_30_minutes", 0))
		var active_squad_ids: Array = active.get("squad_ids", [])
		for instance_id_var: Variant in active_squad_ids:
			var creature: Dictionary = _find_owned_creature(str(instance_id_var))
			if creature.is_empty():
				continue
			var species_key: String = str(creature.get("def_id", creature.get("monster_id", "")))
			var definition: Resource = MONSTER_CATALOG.find_monster(species_key)
			var has_specialty: bool = definition != null and str(definition.get("profession")) == preferred_prof
			var specialty_multiplier: float = (1.0 + spec_bonus / 100.0) if has_specialty else 1.0
			for resource_id_var: Variant in base_rewards.keys():
				var resource_id: String = str(resource_id_var)
				var amount: int = floori(float(base_rewards[resource_id]) * duration_scale * specialty_multiplier)
				total_rewards[resource_id] = int(total_rewards.get(resource_id, 0)) + amount
			var earned_exp: int = roundi(exp_per_30m * duration_scale)
			creature["training_exp"] = int(creature.get("training_exp", 0)) + earned_exp
			total_exp += earned_exp
		for resource_id_var: Variant in total_rewards.keys():
			var resource_id: String = str(resource_id_var)
			var reward_amount: int = int(total_rewards[resource_id])
			resources[resource_id] = int(resources.get(resource_id, 0)) + reward_amount
			save_helper.add_item(resource_id, reward_amount, "resources")
	player_profile["resources"] = resources
	active["active"] = false
	active["squad_ids"] = []
	active["start_unix"] = 0
	active["duration_seconds"] = 0
	player_profile["expedition"] = active
	player_profile["last_expedition_result"] = _expedition_result_text(region_dict, total_rewards, total_exp)
	PLAYER_SAVE.save(player_profile)
	return true

func _expedition_result_text(region_dict: Dictionary, rewards: Dictionary, earned_exp: int) -> String:
	var lines: Array[String] = []
	var region_name: String = str(region_dict.get("display_name", "Chuyến viễn chinh"))
	lines.append("Đã trở về từ %s." % region_name)
	var resource_names := {"food": "Thức ăn", "herbs": "Thảo dược", "fiber": "Sợi", "wood": "Gỗ", "ore": "Quặng", "crystal": "Tinh thể"}
	var reward_parts: Array[String] = []
	for resource_id_var: Variant in rewards.keys():
		var resource_id: String = str(resource_id_var)
		var reward_val: int = int(rewards[resource_id])
		if reward_val > 0:
			var label_name: String = str(resource_names.get(resource_id, resource_id))
			reward_parts.append("%s %d" % [label_name, reward_val])
	if reward_parts.is_empty():
		reward_parts.append("không có tài nguyên")
	lines.append("Thu hoạch: " + "  ·  ".join(reward_parts))
	lines.append("Đội nhận tổng cộng %d EXP huấn luyện." % earned_exp)
	return "\n".join(lines)

func _assigned_worker_ids() -> Dictionary:
	var assigned: Dictionary = {}
	for instance_id in _farm_data().get("workers", []):
		assigned[str(instance_id)] = true
	for instance_id in _lumber_data().get("workers", []):
		assigned[str(instance_id)] = true
	return assigned

func _busy_expedition_ids() -> Dictionary:
	var busy: Dictionary = {}
	var active: Dictionary = player_profile.get("expedition", {})
	if bool(active.get("active", false)):
		for instance_id in active.get("squad_ids", []):
			busy[str(instance_id)] = true
	return busy

func _make_page(title_text: String, section_text: String, show_back: bool = false) -> VBoxContainer:
	page_root = Control.new()
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_root)
	var background := ColorRect.new()
	background.color = Color("#101817")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 540)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	if show_back:
		var back := Button.new()
		back.text = "←  VỀ CĂN CỨ"
		back.custom_minimum_size = Vector2(0, 44)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back.pressed.connect(_show_base)
		layout.add_child(back)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)
	var section := Label.new()
	section.text = section_text
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_theme_color_override("font_color", Color("#8ac9a2"))
	layout.add_child(section)
	return layout

func _show_farm() -> void:
	_clear_page()
	farm_worker_checks.clear()
	farm_notice = ""
	_update_farm_production()
	var layout := _make_page("NÔNG TRẠI", "SẢN XUẤT CĂN CỨ", true)
	var info := Label.new()
	info.text = "Mỗi quái được giao tạo tài nguyên và nhận %d EXP huấn luyện mỗi giờ. Sản lượng giới hạn ở 24 giờ." % int(TRAINING_PROGRESSION.get("base_work_exp_per_hour"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(info)
	farm_resources_label = Label.new()
	farm_resources_label.text = _resource_totals_text()
	farm_resources_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	farm_resources_label.add_theme_color_override("font_color", Color("#b8c9c2"))
	layout.add_child(farm_resources_label)
	farm_pending_label = Label.new()
	farm_pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	farm_pending_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(farm_pending_label)
	var worker_heading := Label.new()
	worker_heading.text = "NHÂN CÔNG  ·  TỐI ĐA %d QUÁI" % MAX_FARM_WORKERS
	worker_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(worker_heading)
	var worker_scroll := ScrollContainer.new()
	worker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(worker_scroll)
	var worker_list := VBoxContainer.new()
	worker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worker_scroll.add_child(worker_list)
	var workers: Array = _farm_data().get("workers", [])
	var traveling_ids := _busy_expedition_ids()
	var owned: Array = []
	owned.append_array(player_profile.get("team", []))
	owned.append_array(player_profile.get("storage", []))
	for creature in owned:
		var monster_id := StringName(str(creature.get("monster_id", "")))
		var instance_id := str(creature.get("instance_id", monster_id))
		var definition: Resource = MONSTER_CATALOG.find_monster(monster_id)
		var monster_name := str(definition.get("display_name")) if definition != null else str(monster_id)
		var profession := _profession_display(str(definition.get("profession"))) if definition != null else ""
		var bonus_text := _farm_bonus_description(definition)
		var check := CheckBox.new()
		check.text = "%s%s%s" % [monster_name, " · " + profession if not profession.is_empty() else "", " · " + bonus_text if not bonus_text.is_empty() else ""]
		check.button_pressed = workers.has(instance_id)
		check.disabled = traveling_ids.has(instance_id)
		if check.disabled:
			check.tooltip_text = "Quái đang Viễn Chinh và chưa thể nhận việc mới."
		check.toggled.connect(func(pressed: bool): _set_farm_worker(instance_id, pressed, check))
		worker_list.add_child(check)
		farm_worker_checks.append(check)
	farm_status_label = Label.new()
	farm_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(farm_status_label)
	var harvest_button := Button.new()
	harvest_button.text = "Thu hoạch"
	harvest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harvest_button.pressed.connect(_harvest_farm)
	layout.add_child(harvest_button)
	_refresh_farm_labels()
	_start_production_timer("farm")

func _set_farm_worker(monster_id: String, assigned: bool, checkbox: CheckBox) -> void:
	_update_farm_production()
	if assigned and _busy_expedition_ids().has(monster_id):
		checkbox.set_pressed_no_signal(false)
		farm_notice = "Quái đang Viễn Chinh và chưa thể nhận việc mới."
		_refresh_farm_labels()
		return
	var farm := _farm_data()
	var workers: Array = farm.get("workers", []).duplicate()
	if assigned and not workers.has(monster_id):
		if workers.size() >= MAX_FARM_WORKERS:
			checkbox.set_pressed_no_signal(false)
			farm_notice = "Nông Trại chỉ nhận tối đa %d quái." % MAX_FARM_WORKERS
			_refresh_farm_labels()
			return
		workers.append(monster_id)
	elif not assigned:
		workers.erase(monster_id)
	farm["workers"] = workers
	farm["last_calculated_unix"] = int(Time.get_unix_time_from_system())
	player_profile["farm"] = farm
	farm_notice = ""
	PLAYER_SAVE.save(player_profile)
	_refresh_farm_labels()

func _update_farm_production(should_save: bool = true) -> void:
	_update_base_work_training_exp()
	var farm := _farm_data()
	var now := int(Time.get_unix_time_from_system())
	var last_time := int(farm.get("last_calculated_unix", now))
	var elapsed := clampi(now - last_time, 0, 86400)
	var pending: Dictionary = farm.get("pending", {"food": 0.0, "herbs": 0.0, "fiber": 0.0})
	var food_rate := 0.0
	var herb_rate := 0.0
	var fiber_rate := 0.0
	for worker_id in farm.get("workers", []):
		food_rate += 10.0
		herb_rate += 2.0
		fiber_rate += 3.0
		var creature := _find_owned_creature(str(worker_id))
		var definition: Resource = MONSTER_CATALOG.find_monster(StringName(str(creature.get("monster_id", ""))))
		if definition == null or str(definition.get("utility_building")) != "farm":
			continue
		var bonus := float(definition.get("utility_bonus_percent")) / 100.0
		var bonus_resource := str(definition.get("utility_bonus_resource"))
		if bonus_resource == "all":
			food_rate += 10.0 * bonus
			herb_rate += 2.0 * bonus
			fiber_rate += 3.0 * bonus
		elif bonus_resource == "food":
			food_rate += 10.0 * bonus
	pending["food"] = float(pending.get("food", 0.0)) + food_rate * elapsed / 3600.0
	pending["herbs"] = float(pending.get("herbs", 0.0)) + herb_rate * elapsed / 3600.0
	pending["fiber"] = float(pending.get("fiber", 0.0)) + fiber_rate * elapsed / 3600.0
	farm["pending"] = pending
	farm["last_calculated_unix"] = now
	player_profile["farm"] = farm
	if should_save:
		PLAYER_SAVE.save(player_profile)

func _harvest_farm() -> void:
	_update_farm_production()
	var farm := _farm_data()
	var pending: Dictionary = farm.get("pending", {})
	var resources: Dictionary = player_profile.get("resources", {})
	for resource_id in ["food", "herbs", "fiber"]:
		var available := floori(float(pending.get(resource_id, 0.0)))
		resources[resource_id] = int(resources.get(resource_id, 0)) + available
		pending[resource_id] = float(pending.get(resource_id, 0.0)) - available
	farm["pending"] = pending
	player_profile["farm"] = farm
	player_profile["resources"] = resources
	PLAYER_SAVE.save(player_profile)
	farm_notice = "Đã thu hoạch tài nguyên sẵn sàng."
	_refresh_farm_labels()

func _refresh_farm_labels() -> void:
	if not is_instance_valid(farm_pending_label):
		return
	var farm := _farm_data()
	var pending: Dictionary = farm.get("pending", {})
	farm_pending_label.text = "Chờ thu hoạch:  Thức ăn %d  ·  Thảo dược %d  ·  Sợi %d" % [
		floori(float(pending.get("food", 0.0))),
		floori(float(pending.get("herbs", 0.0))),
		floori(float(pending.get("fiber", 0.0)))
	]
	if is_instance_valid(farm_resources_label):
		farm_resources_label.text = _resource_totals_text()
	if is_instance_valid(farm_status_label):
		farm_status_label.text = "Nhân công: %d / %d  ·  Mỗi quái tạo 10 thức ăn, 2 thảo dược, 3 sợi và nhận %d EXP/giờ." % [farm.get("workers", []).size(), MAX_FARM_WORKERS, int(TRAINING_PROGRESSION.get("base_work_exp_per_hour"))]
		if not farm_notice.is_empty():
			farm_status_label.text += "\n" + farm_notice

func _start_production_timer(building_id: String) -> void:
	if production_timer == null:
		production_timer = Timer.new()
		production_timer.wait_time = 1.0
		production_timer.timeout.connect(_on_production_timer_tick)
		add_child(production_timer)
	active_production_building = building_id
	last_production_autosave_unix = int(Time.get_unix_time_from_system())
	production_timer.start()

func _on_production_timer_tick() -> void:
	if active_production_building == "farm":
		_update_farm_production(false)
		_refresh_farm_labels()
	elif active_production_building == "lumber_mill":
		_update_lumber_production(false)
		_refresh_lumber_labels()
	var now := int(Time.get_unix_time_from_system())
	if now - last_production_autosave_unix >= 60:
		PLAYER_SAVE.save(player_profile)
		last_production_autosave_unix = now

func _stop_production_timer() -> void:
	if production_timer != null:
		production_timer.stop()
	active_production_building = ""

func _resource_totals_text() -> String:
	var inventory: Dictionary = player_profile.get("resources", {})
	return "Kho: Thức ăn %d  ·  Thảo dược %d  ·  Sợi %d" % [
		int(inventory.get("food", 0)),
		int(inventory.get("herbs", 0)),
		int(inventory.get("fiber", 0))
	]

func _farm_data() -> Dictionary:
	var farm: Dictionary = player_profile.get("farm", {})
	if farm.is_empty():
		farm = {"workers": [], "last_calculated_unix": int(Time.get_unix_time_from_system()), "pending": {"food": 0.0, "herbs": 0.0, "fiber": 0.0}}
		player_profile["farm"] = farm
	return farm

func _get_owned_creatures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var monsters_arr: Variant = player_profile.get("monsters", [])
	if typeof(monsters_arr) == TYPE_ARRAY and not (monsters_arr as Array).is_empty():
		for entry: Variant in (monsters_arr as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry as Dictionary)
		return result
	for group_name: String in ["team", "storage"]:
		var group_arr: Variant = player_profile.get(group_name, [])
		if typeof(group_arr) == TYPE_ARRAY:
			for entry: Variant in (group_arr as Array):
				if typeof(entry) == TYPE_DICTIONARY:
					result.append(entry as Dictionary)
	return result

func _find_owned_creature(instance_id: String) -> Dictionary:
	for creature: Dictionary in _get_owned_creatures():
		if str(creature.get("instance_id", "")) == instance_id:
			return creature
	return {}

func _farm_bonus_description(definition: Resource) -> String:
	if definition == null or str(definition.get("utility_building")) != "farm":
		return ""
	var percent := int(definition.get("utility_bonus_percent"))
	var resource_id := str(definition.get("utility_bonus_resource"))
	if resource_id == "food":
		return "+%d%% thức ăn" % percent
	return "+%d%% sản lượng Nông Trại" % percent

func _profession_display(profession: String) -> String:
	var names := {
		"Herbalist": "Nhà thảo dược",
		"Fisher": "Ngư dân",
		"Wood Gatherer": "Thợ khai thác gỗ"
	}
	return str(names.get(profession, profession))

func _show_lumber_mill() -> void:
	_clear_page()
	lumber_notice = ""
	_update_lumber_production()
	var layout := _make_page("XƯỞNG GỖ", "SẢN XUẤT CĂN CỨ", true)
	var info := Label.new()
	info.text = "Giao quái làm việc để tạo gỗ và nhận %d EXP huấn luyện mỗi giờ. Sản lượng giới hạn ở 24 giờ." % int(TRAINING_PROGRESSION.get("base_work_exp_per_hour"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(info)
	lumber_stock_label = Label.new()
	lumber_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lumber_stock_label.add_theme_color_override("font_color", Color("#b8c9c2"))
	layout.add_child(lumber_stock_label)
	lumber_pending_label = Label.new()
	lumber_pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lumber_pending_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(lumber_pending_label)
	var worker_heading := Label.new()
	worker_heading.text = "NHÂN CÔNG  ·  TỐI ĐA %d QUÁI" % MAX_LUMBER_WORKERS
	worker_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(worker_heading)
	var worker_scroll := ScrollContainer.new()
	worker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(worker_scroll)
	var worker_list := VBoxContainer.new()
	worker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worker_scroll.add_child(worker_list)
	var workers: Array = _lumber_data().get("workers", [])
	var traveling_ids := _busy_expedition_ids()
	var owned: Array = []
	owned.append_array(player_profile.get("team", []))
	owned.append_array(player_profile.get("storage", []))
	for creature in owned:
		var monster_id := StringName(str(creature.get("monster_id", "")))
		var instance_id := str(creature.get("instance_id", monster_id))
		var definition: Resource = MONSTER_CATALOG.find_monster(monster_id)
		var monster_name := str(definition.get("display_name")) if definition != null else str(monster_id)
		var profession := _profession_display(str(definition.get("profession"))) if definition != null else ""
		var bonus_text := _lumber_bonus_description(definition)
		var check := CheckBox.new()
		check.text = "%s%s%s" % [monster_name, " · " + profession if not profession.is_empty() else "", " · " + bonus_text if not bonus_text.is_empty() else ""]
		check.button_pressed = workers.has(instance_id)
		check.disabled = traveling_ids.has(instance_id)
		if check.disabled:
			check.tooltip_text = "Quái đang Viễn Chinh và chưa thể nhận việc mới."
		check.toggled.connect(func(pressed: bool): _set_lumber_worker(instance_id, pressed, check))
		worker_list.add_child(check)
	lumber_status_label = Label.new()
	lumber_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(lumber_status_label)
	var harvest_button := Button.new()
	harvest_button.text = "Thu hoạch"
	harvest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harvest_button.pressed.connect(_harvest_lumber)
	layout.add_child(harvest_button)
	_refresh_lumber_labels()
	_start_production_timer("lumber_mill")

func _set_lumber_worker(instance_id: String, assigned: bool, checkbox: CheckBox) -> void:
	_update_lumber_production()
	if assigned and _busy_expedition_ids().has(instance_id):
		checkbox.set_pressed_no_signal(false)
		lumber_notice = "Quái đang Viễn Chinh và chưa thể nhận việc mới."
		_refresh_lumber_labels()
		return
	var lumber := _lumber_data()
	var workers: Array = lumber.get("workers", []).duplicate()
	if assigned and not workers.has(instance_id):
		if workers.size() >= MAX_LUMBER_WORKERS:
			checkbox.set_pressed_no_signal(false)
			lumber_notice = "Xưởng Gỗ chỉ nhận tối đa %d quái." % MAX_LUMBER_WORKERS
			_refresh_lumber_labels()
			return
		workers.append(instance_id)
	elif not assigned:
		workers.erase(instance_id)
	lumber["workers"] = workers
	lumber["last_calculated_unix"] = int(Time.get_unix_time_from_system())
	player_profile["lumber_mill"] = lumber
	lumber_notice = ""
	PLAYER_SAVE.save(player_profile)
	_refresh_lumber_labels()

func _update_lumber_production(should_save: bool = true) -> void:
	_update_base_work_training_exp()
	var lumber := _lumber_data()
	var now := int(Time.get_unix_time_from_system())
	var last_time := int(lumber.get("last_calculated_unix", now))
	var elapsed := clampi(now - last_time, 0, 86400)
	var wood_rate := 0.0
	for worker_id in lumber.get("workers", []):
		wood_rate += 8.0
		var creature := _find_owned_creature(str(worker_id))
		var definition: Resource = MONSTER_CATALOG.find_monster(StringName(str(creature.get("monster_id", ""))))
		if definition == null or str(definition.get("utility_building")) != "lumber_mill":
			continue
		var bonus_resource := str(definition.get("utility_bonus_resource"))
		if bonus_resource == "wood" or bonus_resource == "all":
			wood_rate += 8.0 * float(definition.get("utility_bonus_percent")) / 100.0
	var pending: Dictionary = lumber.get("pending", {"wood": 0.0})
	pending["wood"] = float(pending.get("wood", 0.0)) + wood_rate * elapsed / 3600.0
	lumber["pending"] = pending
	lumber["last_calculated_unix"] = now
	player_profile["lumber_mill"] = lumber
	if should_save:
		PLAYER_SAVE.save(player_profile)

func _harvest_lumber() -> void:
	_update_lumber_production()
	var lumber := _lumber_data()
	var pending: Dictionary = lumber.get("pending", {})
	var resources: Dictionary = player_profile.get("resources", {})
	var available := floori(float(pending.get("wood", 0.0)))
	resources["wood"] = int(resources.get("wood", 0)) + available
	pending["wood"] = float(pending.get("wood", 0.0)) - available
	lumber["pending"] = pending
	player_profile["lumber_mill"] = lumber
	player_profile["resources"] = resources
	PLAYER_SAVE.save(player_profile)
	lumber_notice = "Đã thu hoạch gỗ sẵn sàng."
	_refresh_lumber_labels()

func _refresh_lumber_labels() -> void:
	if not is_instance_valid(lumber_pending_label):
		return
	var lumber := _lumber_data()
	var pending: Dictionary = lumber.get("pending", {})
	var resources: Dictionary = player_profile.get("resources", {})
	lumber_stock_label.text = "Trong kho: Gỗ %d" % int(resources.get("wood", 0))
	lumber_pending_label.text = "Chờ thu hoạch:  Gỗ %d" % floori(float(pending.get("wood", 0.0)))
	lumber_status_label.text = "Nhân công: %d / %d  ·  Mỗi quái tạo 8 gỗ và nhận %d EXP/giờ." % [lumber.get("workers", []).size(), MAX_LUMBER_WORKERS, int(TRAINING_PROGRESSION.get("base_work_exp_per_hour"))]
	if not lumber_notice.is_empty():
		lumber_status_label.text += "\n" + lumber_notice

func _lumber_data() -> Dictionary:
	var lumber: Dictionary = player_profile.get("lumber_mill", {})
	if lumber.is_empty():
		lumber = {"workers": [], "last_calculated_unix": int(Time.get_unix_time_from_system()), "pending": {"wood": 0.0}}
		player_profile["lumber_mill"] = lumber
	return lumber

func _update_base_work_training_exp() -> void:
	var now := int(Time.get_unix_time_from_system())
	var last_time := int(player_profile.get("last_base_work_exp_unix", now))
	var elapsed := clampi(now - last_time, 0, 86400)
	player_profile["last_base_work_exp_unix"] = now
	var workers: Dictionary = {}
	for worker_id in _farm_data().get("workers", []):
		workers[str(worker_id)] = true
	for worker_id in _lumber_data().get("workers", []):
		workers[str(worker_id)] = true
	var remainders: Dictionary = player_profile.get("base_work_exp_remainders", {})
	var rate := float(TRAINING_PROGRESSION.get("base_work_exp_per_hour"))
	for worker_id in workers:
		var creature := _find_owned_creature(str(worker_id))
		if creature.is_empty():
			continue
		var accumulated := float(remainders.get(worker_id, 0.0)) + rate * elapsed / 3600.0
		var earned := floori(accumulated + 0.000001)
		if earned > 0:
			creature["training_exp"] = int(creature.get("training_exp", 0)) + earned
		remainders[worker_id] = accumulated - earned
	player_profile["base_work_exp_remainders"] = remainders

func _lumber_bonus_description(definition: Resource) -> String:
	if definition == null or str(definition.get("utility_building")) != "lumber_mill":
		return ""
	return "+%d%% sản lượng Xưởng Gỗ" % int(definition.get("utility_bonus_percent"))

func _show_training() -> void:
	_clear_page()
	_update_base_work_training_exp()
	PLAYER_SAVE.save(player_profile)
	var training_tutorial_notice := ""
	if not bool(player_profile.get("training_essence_tutorial_granted", false)):
		var tutorial_inventory: Dictionary = player_profile.get("inventory", {})
		tutorial_inventory["training_essence"] = int(tutorial_inventory.get("training_essence", 0)) + 1
		player_profile["inventory"] = tutorial_inventory
		player_profile["training_essence_tutorial_granted"] = true
		PLAYER_SAVE.save(player_profile)
		training_tutorial_notice = "Bạn nhận được 1 Tinh chất Huấn luyện để thử tăng EXP cho một cá thể."
	var layout := _make_page("SÂN HUẤN LUYỆN", "PHÁT TRIỂN QUÁI THÚ", true)
	var info := Label.new()
	info.text = "EXP chiến đấu và làm việc cộng vào cá thể tham gia. Mỗi quái đang làm việc nhận %d EXP/giờ; Tinh chất cộng EXP cố định. Đủ ngưỡng thì có thể chủ động tăng sao." % int(TRAINING_PROGRESSION.get("base_work_exp_per_hour"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(info)
	if not training_tutorial_notice.is_empty():
		var tutorial_notice := Label.new()
		tutorial_notice.text = training_tutorial_notice
		tutorial_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tutorial_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tutorial_notice.add_theme_color_override("font_color", Color("#e4bd78"))
		layout.add_child(tutorial_notice)
	var max_star_rank := int(TRAINING_PROGRESSION.get("max_star_rank"))
	var rule := Label.new()
	rule.text = "Mốc EXP tăng sao đã chốt  ·  Tối đa %d sao" % max_star_rank
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_color_override("font_color", Color("#e4bd78"))
	layout.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var owned: Array = []
	owned.append_array(player_profile.get("team", []))
	owned.append_array(player_profile.get("storage", []))
	if owned.is_empty():
		var empty := Label.new()
		empty.text = "Bạn chưa có quái thú để huấn luyện."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	for creature in owned:
		var monster_id := StringName(str(creature.get("monster_id", "")))
		var definition: Resource = MONSTER_CATALOG.find_monster(monster_id)
		var monster_name := str(definition.get("display_name")) if definition != null else str(monster_id)
		var rank := clampi(int(creature.get("star_rank", 1)), 1, max_star_rank)
		var exp := int(creature.get("training_exp", 0))
		var cost := _star_upgrade_cost(rank) if rank < max_star_rank else -1
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel_style())
		list.add_child(card)
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 8)
		card.add_child(card_content)
		var details := Label.new()
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if rank >= max_star_rank:
			details.text = "%s  ·  %d sao  ·  %d EXP huấn luyện  ·  Đã đạt tối đa" % [monster_name, rank, exp]
		elif cost < 0:
			details.text = "%s  ·  %d sao  ·  %d EXP huấn luyện  ·  Thiếu cấu hình EXP" % [monster_name, rank, exp]
		else:
			details.text = "%s  ·  %d sao  ·  %d / %d EXP huấn luyện" % [monster_name, rank, exp, cost]
		card_content.add_child(details)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		card_content.add_child(actions)
		var promote := Button.new()
		if rank >= max_star_rank:
			promote.text = "Tối đa"
			promote.disabled = true
		elif cost < 0:
			promote.text = "Thiếu dữ liệu EXP"
			promote.disabled = true
		else:
			promote.text = "Nâng lên %d sao" % (rank + 1)
			promote.disabled = exp < cost
			promote.pressed.connect(_promote_creature.bind(str(creature.get("instance_id", monster_id))))
		promote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(promote)
		var essence_count := _training_essence_count()
		var use_essence := Button.new()
		use_essence.text = "Dùng Tinh chất  ·  %d" % essence_count
		use_essence.disabled = rank >= max_star_rank
		use_essence.tooltip_text = "Mở danh sách tinh chất trong kho để chọn." if essence_count > 0 else "Kho hiện chưa có tinh chất; nút vẫn mở danh sách để xem trạng thái."
		use_essence.pressed.connect(_open_training_essence_dialog.bind(str(creature.get("instance_id", monster_id))))
		use_essence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(use_essence)

func _star_upgrade_cost(current_rank: int) -> int:
	return int(TRAINING_PROGRESSION.call("get_upgrade_cost", current_rank))

func _training_essence_count() -> int:
	var inventory: Dictionary = player_profile.get("inventory", {})
	var essence_definitions: Array = TRAINING_PROGRESSION.get("training_essences")
	var total := 0
	for essence in essence_definitions:
		total += int(inventory.get(str(essence.get("item_id")), 0))
	return total

func _open_training_essence_dialog(instance_id: String) -> void:
	var creature := _find_owned_creature(instance_id)
	if creature.is_empty():
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	page_root.add_child(overlay)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.04, 0.035, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := Label.new()
	title.text = "CHỌN TINH CHẤT HUẤN LUYỆN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	var hint := Label.new()
	hint.text = "Chọn một loại tinh chất để cộng EXP cho cá thể này:"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var choices := VBoxContainer.new()
	content.add_child(choices)
	var choice_group := ButtonGroup.new()
	var inventory: Dictionary = player_profile.get("inventory", {})
	var essence_definitions: Array = TRAINING_PROGRESSION.get("training_essences")
	var available_count := 0
	for essence in essence_definitions:
		var item_id := str(essence.get("item_id"))
		var item_count := int(inventory.get(item_id, 0))
		if item_count <= 0:
			continue
		var choice := CheckBox.new()
		choice.text = "%s    ·    +%d EXP    ·    Còn %d" % [str(essence.get("display_name")), int(essence.get("exp_value")), item_count]
		choice.button_group = choice_group
		choice.set_meta("item_id", item_id)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(choice)
		available_count += 1
		if available_count == 1:
			choice.button_pressed = true
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Hủy"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(overlay.queue_free)
	actions.add_child(cancel)
	var use := Button.new()
	use.text = "Dùng tinh chất" if available_count > 0 else "Đóng"
	use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use.disabled = available_count == 0
	use.pressed.connect(_confirm_training_essence.bind(instance_id, choice_group, overlay))
	actions.add_child(use)
	if available_count == 0:
		hint.text = "Kho chưa có Tinh chất Huấn luyện nào."
		use.disabled = false

func _confirm_training_essence(instance_id: String, choice_group: ButtonGroup, overlay: Control) -> void:
	var selected_choice := choice_group.get_pressed_button()
	if selected_choice == null:
		overlay.queue_free()
		return
	var item_id := StringName(str(selected_choice.get_meta("item_id", "")))
	overlay.queue_free()
	_consume_training_essence(instance_id, item_id)

func _consume_training_essence(instance_id: String, item_id: StringName) -> void:
	var creature := _find_owned_creature(instance_id)
	if creature.is_empty() or item_id == &"":
		return
	var essence: Resource = TRAINING_PROGRESSION.call("find_training_essence", item_id)
	if essence == null:
		return
	var max_star_rank := int(TRAINING_PROGRESSION.get("max_star_rank"))
	if int(creature.get("star_rank", 1)) >= max_star_rank:
		return
	var inventory: Dictionary = player_profile.get("inventory", {})
	var item_key := str(item_id)
	var item_count := int(inventory.get(item_key, 0))
	if item_count <= 0:
		return
	inventory[item_key] = item_count - 1
	creature["training_exp"] = int(creature.get("training_exp", 0)) + int(essence.get("exp_value"))
	player_profile["inventory"] = inventory
	PLAYER_SAVE.save(player_profile)
	_show_training()

func _promote_creature(instance_id: String) -> void:
	var creature := _find_owned_creature(instance_id)
	if creature.is_empty():
		return
	var max_star_rank := int(TRAINING_PROGRESSION.get("max_star_rank"))
	var rank := clampi(int(creature.get("star_rank", 1)), 1, max_star_rank)
	if rank >= max_star_rank:
		return
	var cost := _star_upgrade_cost(rank)
	if cost < 0:
		push_error("Thiếu ngưỡng EXP hợp lệ cho lần nâng sao %d → %d." % [rank, rank + 1])
		return
	var exp := int(creature.get("training_exp", 0))
	if exp < cost:
		return
	creature["training_exp"] = exp - cost
	creature["star_rank"] = rank + 1
	PLAYER_SAVE.save(player_profile)
	_show_training()

func _clear_page() -> void:
	if active_production_building == "farm":
		_update_farm_production()
	elif active_production_building == "lumber_mill":
		_update_lumber_production()
	_stop_production_timer()
	if is_instance_valid(page_root):
		page_root.queue_free()
	page_root = null
	expedition_status_label = null
	expedition_selection_label = null
	expedition_region_picker = null
	expedition_duration_picker = null
	expedition_member_checks.clear()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1d2a27")
	style.border_color = Color("#3e6256")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	return style
