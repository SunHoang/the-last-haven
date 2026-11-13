extends Resource
class_name ExpeditionRegionData

@export var region_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var durations_minutes: Array[int] = [15, 30, 120]
@export var base_rewards_per_30_minutes: Dictionary = {}
@export var preferred_profession: String = ""
@export_range(0, 300) var specialization_bonus_percent := 25
@export_range(0, 10000) var training_exp_per_30_minutes := 15
