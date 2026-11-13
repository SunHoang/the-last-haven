extends Resource
class_name EncounterEnemyData

@export var monster_id: StringName
@export_range(1, 10) var star_rank := 1
@export var exp_reward_override := -1
@export var loot_table_override: Array[Resource] = []
