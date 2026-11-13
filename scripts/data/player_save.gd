extends RefCounted
class_name PlayerSave

const SAVE_PATH := "user://game_state.json"
const SCHEMA_VERSION := "1.0.0"
const MAX_RESOURCE_CAPACITY := 10000

const VALID_ZONES := [
	"currencies",
	"resources",
	"items",
	"monster_fragments"
]

var game_state: Dictionary = {}
var _reservation_counter: int = 0

func _init(initial_state: Dictionary = {}) -> void:
	if initial_state.is_empty():
		game_state = create_default_state()
	else:
		game_state = initial_state
		_ensure_state_structure()

static func create_default_state() -> Dictionary:
	return {
		"metadata": {
			"schema_version": SCHEMA_VERSION,
			"save_timestamp": int(Time.get_unix_time_from_system())
		},
		"inventory": {
			"currencies": {
				"gold": 0,
				"soul_dust": 0,
				"premium": 0
			},
			"resources": {},
			"items": {},
			"monster_fragments": {},
			"reservations": {}
		},
		"base": {
			"buildings": []
		},
		"monsters": [],
		"expedition": create_default_passive_expedition(),
		"exploration": create_default_active_exploration(),
		"last_expedition_result": ""
	}

static func create_default_passive_expedition() -> Dictionary:
	return {
		"mode": "passive_expedition",
		"active": false,
		"region_id": "core:region:ancient_forest",
		"region_name": "Rừng Cổ Đại",
		"squad_ids": [],
		"start_unix": 0,
		"duration_seconds": 0,
		"available_regions": get_default_expedition_regions()
	}

static func create_default_active_exploration() -> Dictionary:
	return {
		"mode": "active_exploration",
		"active": false,
		"region_id": "core:region:ancient_forest",
		"region_name": "Rừng Cổ Đại",
		"map_seed": 0,
		"current_layer": 0,
		"total_layers": 7,
		"current_node_id": "layer_0_start",
		"supply": 10,
		"max_supply": 10,
		"squad_ids": [],
		"dag_nodes": [],
		"pending_loot": {}
	}

static func get_default_expedition_regions() -> Array[Dictionary]:
	return [
		{
			"region_id": "core:region:ancient_forest",
			"legacy_id": "ancient_forest",
			"display_name": "Rừng Cổ Đại",
			"description": "Một khu rừng giàu thức ăn, thảo dược và sợi. Nhà thảo dược tìm thêm vật liệu tại đây.",
			"durations_minutes": [15, 30, 120],
			"base_rewards_per_30_minutes": {"food": 10, "herbs": 4, "fiber": 6},
			"preferred_profession": "Herbalist",
			"specialization_bonus_percent": 25,
			"training_exp_per_30_minutes": 15
		}
	]

static func get_expedition_regions(state: Dictionary) -> Array:
	var exp_state: Dictionary = state.get("expedition", {})
	var regions: Variant = exp_state.get("available_regions", [])
	if typeof(regions) == TYPE_ARRAY and not (regions as Array).is_empty():
		return regions as Array
	return get_default_expedition_regions()

static func find_expedition_region(state: Dictionary, region_id: String) -> Dictionary:
	var regions: Array = get_expedition_regions(state)
	for entry: Variant in regions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var region_dict: Dictionary = entry
		var r_id: String = str(region_dict.get("region_id", ""))
		var leg_id: String = str(region_dict.get("legacy_id", ""))
		if r_id == region_id or leg_id == region_id or ("core:region:" + region_id) == r_id:
			return region_dict
	if not regions.is_empty() and typeof(regions[0]) == TYPE_DICTIONARY:
		return regions[0] as Dictionary
	return {}

static func load_or_create(default_roster: Resource = null) -> Dictionary:
	var instance := PlayerSave.new()
	if FileAccess.file_exists(SAVE_PATH):
		if instance.load_from_disk(SAVE_PATH) == OK:
			return instance.game_state
	if default_roster != null and default_roster.get("team_ids") != null:
		var team_ids: Variant = default_roster.get("team_ids")
		if typeof(team_ids) == TYPE_ARRAY:
			var idx: int = 0
			for m_id: Variant in (team_ids as Array):
				idx += 1
				var slug: String = str(m_id)
				var def_id: String = slug if slug.begins_with("core:species:") else "core:species:" + slug
				instance.add_monster(def_id, "mon_uuid_%02d" % idx, 1, 0, 0, "team")
	instance.save_to_disk(SAVE_PATH)
	return instance.game_state

static func save(state: Dictionary, path: String = SAVE_PATH) -> Error:
	var instance := PlayerSave.new(state)
	return instance.save_to_disk(path)

func _ensure_state_structure() -> void:
	if not game_state.has("metadata") or typeof(game_state["metadata"]) != TYPE_DICTIONARY:
		game_state["metadata"] = {
			"schema_version": SCHEMA_VERSION,
			"save_timestamp": int(Time.get_unix_time_from_system())
		}
	if not game_state.has("inventory") or typeof(game_state["inventory"]) != TYPE_DICTIONARY:
		game_state["inventory"] = {}
	var inv: Dictionary = game_state["inventory"]
	for zone in ["currencies", "resources", "items", "monster_fragments", "reservations"]:
		if not inv.has(zone) or typeof(inv[zone]) != TYPE_DICTIONARY:
			inv[zone] = {}
	if not game_state.has("base") or typeof(game_state["base"]) != TYPE_DICTIONARY:
		game_state["base"] = {"buildings": []}
	if not game_state.has("monsters") or typeof(game_state["monsters"]) != TYPE_ARRAY:
		game_state["monsters"] = []
	if not game_state.has("expedition") or typeof(game_state["expedition"]) != TYPE_DICTIONARY:
		game_state["expedition"] = create_default_passive_expedition()
	else:
		var exp_dict: Dictionary = game_state["expedition"]
		if not exp_dict.has("available_regions") or typeof(exp_dict["available_regions"]) != TYPE_ARRAY:
			exp_dict["available_regions"] = get_default_expedition_regions()
	if not game_state.has("exploration") or typeof(game_state["exploration"]) != TYPE_DICTIONARY:
		game_state["exploration"] = create_default_active_exploration()
	if not game_state.has("last_expedition_result"):
		game_state["last_expedition_result"] = ""

func _resolve_zone(item_id: String, preferred_zone: String = "") -> String:
	if preferred_zone in VALID_ZONES:
		return preferred_zone

	var inv: Dictionary = game_state["inventory"]
	for zone in VALID_ZONES:
		var zone_dict: Dictionary = inv.get(zone, {})
		if zone_dict.has(item_id):
			return zone

	if item_id in ["gold", "soul_dust", "premium"] or item_id.begins_with("core:currency:"):
		return "currencies"
	if item_id.begins_with("core:fragment:") or item_id.ends_with("_fragment"):
		return "monster_fragments"
	if item_id.begins_with("core:resource:") or item_id in [
		"core:item:wood",
		"core:item:stone",
		"core:item:iron_ore",
		"core:item:copper_ore",
		"core:item:coal",
		"core:item:crystal",
		"core:item:food",
		"core:item:herbs",
		"core:item:fiber"
	]:
		return "resources"
	return "items"

func get_total_balance(item_id: String, zone: String = "") -> int:
	_ensure_state_structure()
	var target_zone := _resolve_zone(item_id, zone)
	var zone_dict: Dictionary = game_state["inventory"].get(target_zone, {})
	return maxi(0, int(zone_dict.get(item_id, 0)))

func get_reserved_amount(item_id: String) -> int:
	_ensure_state_structure()
	var reservations: Dictionary = game_state["inventory"].get("reservations", {})
	var reserved_total: int = 0
	for res_key in reservations.keys():
		var res_entry: Variant = reservations[res_key]
		if typeof(res_entry) == TYPE_DICTIONARY and str(res_entry.get("item_id", "")) == item_id:
			reserved_total += maxi(0, int(res_entry.get("amount", 0)))
	return reserved_total

## Tính số lượng khả dụng thực tế: Available = Total - Reserved
func get_available_balance(item_id: String, zone: String = "") -> int:
	var total := get_total_balance(item_id, zone)
	var reserved := get_reserved_amount(item_id)
	return maxi(0, total - reserved)

## Thêm vật phẩm vào kho theo phân khu (5-Zone Inventory)
func add_item(item_id: String, amount: int, zone: String = "") -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	_ensure_state_structure()
	var target_zone := _resolve_zone(item_id, zone)
	var zone_dict: Dictionary = game_state["inventory"][target_zone]

	if target_zone == "resources":
		var current_global_resources := _get_total_resource_storage_used()
		if current_global_resources + amount > MAX_RESOURCE_CAPACITY:
			push_warning("Kho tài nguyên (Resource Storage) đã vượt giới hạn %d." % MAX_RESOURCE_CAPACITY)
			return false

	var current_amount := maxi(0, int(zone_dict.get(item_id, 0)))
	zone_dict[item_id] = current_amount + amount
	return true

## Đặt chỗ vật phẩm (Input Reservation) để các công trình Auto không dùng lẹm
func reserve_item(item_id: String, amount: int, locked_by: String = "manual_queue", reservation_id: String = "") -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	if get_available_balance(item_id) < amount:
		return false

	var reservations: Dictionary = game_state["inventory"]["reservations"]
	var res_key := reservation_id
	if res_key.is_empty():
		_reservation_counter += 1
		res_key = "res_%02d" % _reservation_counter
		while reservations.has(res_key):
			_reservation_counter += 1
			res_key = "res_%02d" % _reservation_counter

	if reservations.has(res_key) and typeof(reservations[res_key]) == TYPE_DICTIONARY:
		var existing: Dictionary = reservations[res_key]
		if str(existing.get("item_id", "")) == item_id and str(existing.get("locked_by", "")) == locked_by:
			existing["amount"] = int(existing.get("amount", 0)) + amount
			return true

	reservations[res_key] = {
		"item_id": item_id,
		"amount": amount,
		"locked_by": locked_by
	}
	return true

## Tiêu thụ vật phẩm. Mặc định chỉ trừ trên phần Available (Total - Reserved),
## trừ khi truyền locked_by để giải phóng và tiêu thụ trực tiếp từ phần đã đặt chỗ.
func consume_item(item_id: String, amount: int, zone: String = "", locked_by: String = "") -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	_ensure_state_structure()
	var target_zone := _resolve_zone(item_id, zone)
	var zone_dict: Dictionary = game_state["inventory"][target_zone]
	var total_balance := get_total_balance(item_id, target_zone)

	if locked_by.is_empty():
		if get_available_balance(item_id, target_zone) < amount:
			return false
	else:
		if total_balance < amount:
			return false
		_consume_from_reservations(item_id, amount, locked_by)

	var remaining := total_balance - amount
	if remaining > 0:
		zone_dict[item_id] = remaining
	else:
		zone_dict.erase(item_id)
	return true

func _consume_from_reservations(item_id: String, amount: int, locked_by: String) -> void:
	var reservations: Dictionary = game_state["inventory"]["reservations"]
	var remaining_to_unlock := amount
	var keys_to_erase: Array[String] = []

	for res_key in reservations.keys():
		if remaining_to_unlock <= 0:
			break
		var entry: Variant = reservations[res_key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("item_id", "")) == item_id and str(entry.get("locked_by", "")) == locked_by:
			var res_amount := maxi(0, int(entry.get("amount", 0)))
			var deduct := mini(res_amount, remaining_to_unlock)
			res_amount -= deduct
			remaining_to_unlock -= deduct
			if res_amount <= 0:
				keys_to_erase.append(str(res_key))
			else:
				entry["amount"] = res_amount

	for key in keys_to_erase:
		reservations.erase(key)

func _get_total_resource_storage_used() -> int:
	var resources: Dictionary = game_state["inventory"].get("resources", {})
	var total := 0
	for count in resources.values():
		total += maxi(0, int(count))
	return total

## Thêm một cá thể quái thú mới vào mảng monsters
func add_monster(
	def_id: String,
	instance_id: String = "",
	star: int = 1,
	ascension_level: int = 0,
	training_exp: int = 0,
	location_id: String = "roster"
) -> Dictionary:
	_ensure_state_structure()
	var final_id := instance_id
	if final_id.is_empty():
		final_id = "mon_uuid_%d_%d" % [int(Time.get_unix_time_from_system()), game_state["monsters"].size() + 1]

	var monster_instance := {
		"instance_id": final_id,
		"def_id": def_id,
		"star": clampi(star, 1, 6),
		"ascension_level": clampi(ascension_level, 0, 20),
		"training_exp": maxi(0, training_exp),
		"location_id": location_id
	}
	game_state["monsters"].append(monster_instance)
	return monster_instance

func save_to_disk(path: String = SAVE_PATH) -> Error:
	_ensure_state_structure()
	game_state["metadata"]["save_timestamp"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(game_state, "\t"))
	file.close()
	return OK

func load_from_disk(path: String = SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		game_state = create_default_state()
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	game_state = parsed
	_ensure_state_structure()
	return OK

