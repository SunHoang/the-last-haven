extends Resource
class_name ExpeditionCatalogData

@export var regions: Array[Resource] = []

func find_region(region_id: Variant) -> Resource:
	var target_id: String = str(region_id)
	for region: Resource in regions:
		if region == null:
			continue
		var r_id: String = str(region.get("region_id"))
		var def_id: String = str(region.get("def_id")) if region.get("def_id") != null else ""
		if r_id == target_id or def_id == target_id or ("core:region:" + r_id) == target_id:
			return region
	return null

func to_state_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region: Resource in regions:
		if region == null:
			continue
		var r_id: String = str(region.get("region_id"))
		var durations: Array = region.get("durations_minutes") if region.get("durations_minutes") != null else [15, 30, 120]
		var rewards: Dictionary = region.get("base_rewards_per_30_minutes") if region.get("base_rewards_per_30_minutes") != null else {}
		result.append({
			"region_id": r_id if r_id.begins_with("core:region:") else "core:region:" + r_id,
			"legacy_id": r_id,
			"display_name": str(region.get("display_name")),
			"description": str(region.get("description")),
			"durations_minutes": durations.duplicate(),
			"base_rewards_per_30_minutes": rewards.duplicate(true),
			"preferred_profession": str(region.get("preferred_profession")),
			"specialization_bonus_percent": int(region.get("specialization_bonus_percent")),
			"training_exp_per_30_minutes": int(region.get("training_exp_per_30_minutes"))
		})
	return result

