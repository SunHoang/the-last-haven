extends Resource
class_name SkillData

@export var skill_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(0, 100) var energy_cost := 0
@export var effect_type: StringName = &"damage"
@export var multiplier := 1.0
@export var duration := 0
@export var regen_multiplier := 0.0
@export_range(0.0, 1.0) var shield_percent := 0.0
@export var defense_modifier := 0.0
@export var target: StringName = &"enemy"
