extends Resource
class_name TrainingProgressionData

@export_range(2, 10) var max_star_rank := 10
@export var star_upgrade_exp: Array[int] = [100, 500, 2000, 5000, 10000, 20000, 35000, 60000, 100000]
@export var training_essences: Array[Resource] = []
@export_range(0, 1000) var base_work_exp_per_hour := 30

func get_upgrade_cost(current_rank: int) -> int:
	if current_rank < 1 or current_rank >= max_star_rank:
		return -1
	var index := current_rank - 1
	if index >= star_upgrade_exp.size() or star_upgrade_exp[index] < 0:
		return -1
	return star_upgrade_exp[index]

func find_training_essence(item_id: StringName) -> Resource:
	for essence in training_essences:
		if essence.get("item_id") == item_id:
			return essence
	return null
