extends Resource
class_name MonsterCatalogData

@export var monsters: Array[Resource] = []

func find_monster(id_or_slug: Variant) -> Resource:
	var target: String = str(id_or_slug)
	for monster: Resource in monsters:
		if monster == null:
			continue
		var def_id: String = str(monster.get("def_id")) if monster.get("def_id") != null else ""
		var legacy_id: String = str(monster.get("monster_id")) if monster.get("monster_id") != null else ""
		if def_id == target or legacy_id == target:
			return monster
		if not legacy_id.is_empty() and ("core:species:" + legacy_id) == target:
			return monster
		if not def_id.is_empty() and def_id.ends_with(":" + target):
			return monster
	return null

