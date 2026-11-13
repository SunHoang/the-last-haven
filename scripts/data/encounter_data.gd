extends Resource
class_name EncounterData

@export var encounter_id: StringName
@export var display_name: String
@export_range(1, 100) var starting_energy := 30
@export_range(1, 100) var max_rounds := 30
@export_range(1, 12) var max_allies := 3
@export_range(1, 12) var max_enemies := 3
@export var enemies: Array[Resource] = []
