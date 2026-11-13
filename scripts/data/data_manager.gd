extends Node

const MONSTERS_DIR_PATH := "res://data/monsters"
const MONSTERS_JSON_PATH := "res://data/monsters.json"
const ROSTER_JSON_PATH := "res://data/player/roster.json"

## Cơ sở dữ liệu loài quái thú (MonsterData) nạp từ các file .tres trong res://data/monsters/
## Key chính là def_id (vd: "core:species:mossling").
var monster_db: Dictionary = {}

## Dữ liệu JSON đọc từ res://data/monsters.json
var monsters_json_data: Dictionary = {}

## Dữ liệu đội hình / roster khởi đầu đọc từ res://data/player/roster.json
var roster_data: Dictionary = {}

func _ready() -> void:
	load_all_data()

func load_all_data() -> void:
	load_monster_resources(MONSTERS_DIR_PATH)
	monsters_json_data = load_json_file(MONSTERS_JSON_PATH)
	roster_data = load_json_file(ROSTER_JSON_PATH)

## Tự động quét thư mục data/monsters/ và nạp toàn bộ MonsterData (.tres) vào monster_db
func load_monster_resources(dir_path: String = MONSTERS_DIR_PATH) -> void:
	monster_db.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[DataManager] Không thể mở thư mục: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var clean_name: String = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres") and clean_name != "catalog.tres":
				var full_path: String = dir_path.path_join(clean_name)
				var res: Resource = ResourceLoader.load(full_path)
				if res is MonsterData:
					var monster_res: MonsterData = res as MonsterData
					var key: String = monster_res.def_id.strip_edges()
					if key.is_empty():
						var slug: String = clean_name.get_basename()
						key = "core:species:" + slug
					monster_db[key] = monster_res
				elif res != null and (res.get("def_id") != null or res.get("monster_id") != null):
					var raw_id: String = str(res.get("def_id") if res.get("def_id") != null else res.get("monster_id"))
					if not raw_id.is_empty():
						var norm_id: String = raw_id if raw_id.begins_with("core:species:") else "core:species:" + raw_id
						monster_db[norm_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

## Đọc và parse một file JSON bất kỳ sang Dictionary
func load_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_warning("[DataManager] File JSON không tồn tại: %s" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] Không thể mở file JSON: %s (Error %d)" % [file_path, FileAccess.get_open_error()])
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	if typeof(parsed) == TYPE_ARRAY:
		return {"items": parsed}

	push_error("[DataManager] Lỗi cú pháp JSON trong file: %s" % file_path)
	return {}

## Tra cứu MonsterData từ monster_db theo def_id ("core:species:mossling") hoặc slug ("mossling")
func get_monster_data(def_id_or_slug: String) -> Resource:
	if def_id_or_slug.is_empty():
		return null
	if monster_db.has(def_id_or_slug):
		return monster_db[def_id_or_slug] as Resource
	var prefixed: String = "core:species:" + def_id_or_slug
	if monster_db.has(prefixed):
		return monster_db[prefixed] as Resource
	return null
