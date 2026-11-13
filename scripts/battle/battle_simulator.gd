extends RefCounted
class_name BattleSimulator

const ACTION_BAR_THRESHOLD := 1000
const ICE_ACTION_DELAY_POINTS := 50 # 5% của 1000

const STARTING_ENERGY := 30
const ASCENSION_15_BONUS_ENERGY := 10
const MAX_ENERGY := 100
const NORMAL_ATTACK_ENERGY_GAIN := 20
const DAMAGE_TAKEN_ENERGY_GAIN := 10
const SKILL_1_ENERGY_COST := 40
const SKILL_2_ENERGY_COST := 80

const DEFAULT_CRIT_RATE := 0.10
const DEFAULT_CRIT_MULTIPLIER := 1.50
const AETHER_DEF_PIERCE := 0.20
const AETHER_SHIELD_DAMAGE_MULTIPLIER := 1.50

## Bảng khắc hệ 10 Nguyên Tố theo Master Context:
## - Base Circle: Nature > Earth > Electric > Water > Fire > Nature
## - Environment Triangle: Ice > Nature/Wind, Wind > Earth/Water
## - Duality: Light <-> Dark (Tương khắc 2 chiều x1.5)
const ELEMENT_STRONG_AGAINST := {
	"Nature": ["Earth"],
	"Earth": ["Electric"],
	"Electric": ["Water"],
	"Water": ["Fire"],
	"Fire": ["Nature"],
	"Ice": ["Nature", "Wind"],
	"Wind": ["Earth", "Water"],
	"Light": ["Dark"],
	"Dark": ["Light"],
	"Aether": []
}

static func get_starting_energy(unit: Dictionary) -> int:
	var base_energy: int = STARTING_ENERGY
	if int(unit.get("ascension_level", 0)) >= 15:
		base_energy += ASCENSION_15_BONUS_ENERGY
	return clampi(base_energy, 0, MAX_ENERGY)

static func effective_stat(unit: Dictionary, stat_name: String) -> float:
	var value: float = float(unit.get(stat_name, 0))
	var modifier: float = 0.0
	var effects: Array = unit.get("effects", [])
	for effect_var: Variant in effects:
		if typeof(effect_var) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_var
		if str(effect.get("stat", "")) == stat_name:
			modifier += float(effect.get("modifier", 0.0))
		if stat_name == "spd" and str(effect.get("type", "")) == "bind":
			modifier -= 0.30
	return maxf(1.0, value * (1.0 + modifier))

static func element_multiplier(attack_element: String, target_element: String) -> float:
	if attack_element == "Light" and target_element == "Dark":
		return 1.5
	if attack_element == "Dark" and target_element == "Light":
		return 1.5

	var strong_targets: Array = ELEMENT_STRONG_AGAINST.get(attack_element, [])
	if strong_targets.has(target_element):
		return 1.5

	var target_strong_against: Array = ELEMENT_STRONG_AGAINST.get(target_element, [])
	if target_strong_against.has(attack_element):
		return 0.5

	return 1.0

static func is_unit_buffed(unit: Dictionary) -> bool:
	if int(unit.get("shield", 0)) > 0:
		return true
	var effects: Array = unit.get("effects", [])
	for effect_var: Variant in effects:
		if typeof(effect_var) != TYPE_DICTIONARY:
			continue
		var effect_type: String = str((effect_var as Dictionary).get("type", ""))
		if effect_type in ["atk_up", "def_up", "spd_up", "regen", "shield"]:
			return true
	return false

## Công thức sát thương có kiểm tra Chí mạng (Crit), Khắc hệ (10 hệ) và Xuyên Giáp 20% (hệ Aether)
static func calculate_damage(
	attacker: Dictionary,
	target: Dictionary,
	multiplier: float,
	random_multiplier: float = 1.0,
	ignore_element: bool = false,
	is_crit: bool = false
) -> int:
	var attack: float = effective_stat(attacker, "atk")
	var defense: float = effective_stat(target, "def")
	var attacker_element: String = str(attacker.get("element", "Nature"))
	var target_element: String = str(target.get("element", "Nature"))

	# Hệ Aether xuyên 20% DEF của mục tiêu
	var armor_pierce: float = float(attacker.get("armor_pierce", 0.0))
	if attacker_element == "Aether":
		armor_pierce = maxf(armor_pierce, AETHER_DEF_PIERCE)
	var effective_defense: float = maxf(0.0, defense * (1.0 - clampf(armor_pierce, 0.0, 1.0)))

	var element_scale: float = 1.0 if ignore_element else element_multiplier(attacker_element, target_element)
	var crit_scale: float = float(attacker.get("crit_multiplier", DEFAULT_CRIT_MULTIPLIER)) if is_crit else 1.0

	var raw_damage: float = attack * multiplier * element_scale * crit_scale * (100.0 / (100.0 + effective_defense)) * random_multiplier

	# Hệ Light: Gây thêm +10% sát thương chuẩn nếu mục tiêu đang có Buff
	if attacker_element == "Light" and is_unit_buffed(target):
		raw_damage += attack * multiplier * 0.10

	return maxi(1, roundi(raw_damage))

static func resolve_attack_command(attacker: Dictionary, target: Dictionary, command: Dictionary, random_multiplier: float = 1.0) -> Dictionary:
	var attacker_after: Dictionary = attacker.duplicate(true)
	var target_after: Dictionary = target.duplicate(true)
	var attacker_element: String = str(attacker_after.get("element", "Nature"))

	var is_crit: bool = bool(command.get("is_crit", false))
	if not command.has("is_crit") and command.has("crit_roll"):
		var crit_rate: float = float(attacker_after.get("crit_rate", DEFAULT_CRIT_RATE))
		is_crit = float(command.get("crit_roll", 1.0)) < crit_rate

	var is_normal_attack: bool = bool(command.get("is_normal_attack", not command.has("energy_cost")))
	if is_normal_attack:
		attacker_after["energy"] = clampi(int(attacker_after.get("energy", STARTING_ENERGY)) + NORMAL_ATTACK_ENERGY_GAIN, 0, MAX_ENERGY)
	else:
		var energy_cost: int = int(command.get("energy_cost", 0))
		attacker_after["energy"] = clampi(int(attacker_after.get("energy", STARTING_ENERGY)) - energy_cost, 0, MAX_ENERGY)

	var incoming_damage: int = calculate_damage(
		attacker_after,
		target_after,
		float(command.get("multiplier", 1.0)),
		random_multiplier,
		bool(command.get("ignore_element", false)),
		is_crit
	)

	var current_shield: int = maxi(0, int(target_after.get("shield", 0)))
	var absorbed: int = 0
	var hp_damage: int = incoming_damage

	# Hệ Aether: Gây x1.5 sát thương chuyên biệt lên Khiên (Anti-Shield)
	if current_shield > 0:
		if attacker_element == "Aether":
			var effective_shield_damage: int = roundi(float(incoming_damage) * AETHER_SHIELD_DAMAGE_MULTIPLIER)
			var shield_broken: int = mini(current_shield, effective_shield_damage)
			target_after["shield"] = current_shield - shield_broken
			absorbed = mini(incoming_damage, roundi(float(shield_broken) / AETHER_SHIELD_DAMAGE_MULTIPLIER))
			hp_damage = maxi(0, incoming_damage - absorbed)
		else:
			absorbed = mini(current_shield, incoming_damage)
			hp_damage = incoming_damage - absorbed
			target_after["shield"] = current_shield - absorbed

	target_after["hp"] = maxi(0, int(target_after.get("hp", 0)) - hp_damage)
	target_after["energy"] = clampi(int(target_after.get("energy", STARTING_ENERGY)) + DAMAGE_TAKEN_ENERGY_GAIN, 0, MAX_ENERGY)

	var events: Array[Dictionary] = [{
		"type": "damage_received",
		"target_id": str(target_after.get("id", "")),
		"incoming": incoming_damage,
		"absorbed": absorbed,
		"hp_damage": hp_damage,
		"hp_after": target_after["hp"],
		"is_crit": is_crit
	}]

	# Hệ Dark: Hút máu 10% sát thương thực tế; lượng dư chuyển thành Shield
	if attacker_element == "Dark" and hp_damage > 0 and int(attacker_after.get("hp", 0)) > 0:
		var lifesteal_total: int = maxi(1, roundi(float(hp_damage) * 0.10))
		var max_hp: int = maxi(1, int(attacker_after.get("max_hp", 100)))
		var cur_hp: int = int(attacker_after.get("hp", 0))
		var healed: int = mini(max_hp - cur_hp, lifesteal_total)
		var excess_shield: int = maxi(0, lifesteal_total - healed)
		attacker_after["hp"] = cur_hp + healed
		if excess_shield > 0:
			attacker_after["shield"] = int(attacker_after.get("shield", 0)) + excess_shield
		events.append({
			"type": "lifesteal",
			"source_id": str(attacker_after.get("id", "")),
			"healed": healed,
			"excess_shield": excess_shield,
			"hp_after": attacker_after["hp"]
		})

	# Hệ Ice: Giảm trực tiếp 5% thanh Action Bar của mục tiêu (50 điểm, không thể kháng)
	if attacker_element == "Ice" and int(target_after.get("hp", 0)) > 0:
		if target_after.has("action_bar"):
			target_after["action_bar"] = maxi(0, int(target_after.get("action_bar", 0)) - ICE_ACTION_DELAY_POINTS)
		events.append({
			"type": "action_delay",
			"target_id": str(target_after.get("id", "")),
			"delay_points": ICE_ACTION_DELAY_POINTS
		})

	if str(target_after.get("passive", "")) == "thorny_hide" and hp_damage > 0 and not attacker_after.is_empty() and int(attacker_after.get("hp", 0)) > 0:
		var reflected: int = maxi(1, roundi(float(hp_damage) * 0.1))
		attacker_after["hp"] = maxi(0, int(attacker_after.get("hp", 0)) - reflected)
		events.append({
			"type": "damage_reflected",
			"source_id": str(target_after.get("id", "")),
			"target_id": str(attacker_after.get("id", "")),
			"amount": reflected,
			"hp_after": attacker_after["hp"]
		})

	var applied_effect: String = str(command.get("effect_type", ""))
	if not applied_effect.is_empty() and int(target_after["hp"]) > 0:
		target_after = apply_effect(target_after, applied_effect, int(command.get("duration", 0)), float(command.get("amount", 0.0)), false, float(command.get("modifier", 0.0)))
		events.append({
			"type": "effect_applied",
			"target_id": str(target_after.get("id", "")),
			"effect": applied_effect,
			"duration": int(command.get("duration", 0))
		})

	return {
		"attacker": attacker_after,
		"target": target_after,
		"hp_damage": hp_damage,
		"is_crit": is_crit,
		"events": events
	}

static func resolve_skill_command(allies: Array, enemies: Array, command: Dictionary) -> Dictionary:
	var updated_allies: Array = allies.duplicate(true)
	var updated_enemies: Array = enemies.duplicate(true)
	var actor_index: int = int(command.get("actor_index", -1))
	if actor_index < 0 or actor_index >= updated_allies.size() + updated_enemies.size():
		return {"allies": updated_allies, "enemies": updated_enemies, "events": []}

	var actor_is_enemy: bool = actor_index >= updated_allies.size()
	var actor_team_index: int = actor_index - updated_allies.size() if actor_is_enemy else actor_index
	var friendly_team: Array = updated_enemies if actor_is_enemy else updated_allies
	var opposing_team: Array = updated_allies if actor_is_enemy else updated_enemies
	var actor: Dictionary = friendly_team[actor_team_index]
	var skill: Dictionary = command.get("skill", {})
	var effect: String = str(skill.get("effect", skill.get("effect_type", "")))
	var skill_cost: int = int(skill.get("cost", skill.get("energy_cost", SKILL_1_ENERGY_COST)))
	var events: Array[Dictionary] = []

	match effect:
		"damage", "damage_bind":
			var target_index: int = int(command.get("opponent_target_index", -1))
			if target_index < 0 or target_index >= opposing_team.size() or int(opposing_team[target_index]["hp"]) <= 0:
				return {"allies": updated_allies, "enemies": updated_enemies, "events": events}
			var attack_command := {
				"multiplier": float(skill.get("multiplier", 1.0)),
				"energy_cost": skill_cost,
				"is_normal_attack": false
			}
			if command.has("is_crit"):
				attack_command["is_crit"] = bool(command.get("is_crit", false))
			if effect == "damage_bind":
				attack_command["effect_type"] = "bind"
				attack_command["duration"] = int(skill.get("duration", 0))
			var attack_result: Dictionary = resolve_attack_command(actor, opposing_team[target_index], attack_command, float(command.get("random_multiplier", 1.0)))
			friendly_team[actor_team_index] = attack_result["attacker"]
			opposing_team[target_index] = attack_result["target"]
			events.append_array(attack_result["events"])
		"team_heal_regen":
			actor["energy"] = clampi(int(actor.get("energy", STARTING_ENERGY)) - skill_cost, 0, MAX_ENERGY)
			friendly_team[actor_team_index] = actor
			var heal_amount: int = roundi(effective_stat(actor, "atk") * float(skill.get("multiplier", 1.0)))
			var regen_amount: int = roundi(effective_stat(actor, "atk") * float(skill.get("regen_multiplier", 0.0)))
			for index: int in range(friendly_team.size()):
				var member: Dictionary = friendly_team[index]
				if int(member["hp"]) <= 0:
					continue
				var healed: int = _heal_unit(member, heal_amount)
				friendly_team[index] = apply_effect(member, "regen", int(skill.get("duration", 0)), regen_amount, index == actor_team_index)
				events.append({"type": "healed", "target_id": str(member.get("id", "")), "amount": healed, "hp_after": friendly_team[index]["hp"]})
				events.append({"type": "effect_applied", "target_id": str(member.get("id", "")), "effect": "regen", "duration": int(skill.get("duration", 0))})
		"self_shield_defense":
			actor["energy"] = clampi(int(actor.get("energy", STARTING_ENERGY)) - skill_cost, 0, MAX_ENERGY)
			var shield_amount: int = roundi(float(actor.get("max_hp", 0)) * float(skill.get("shield_percent", 0.0)))
			friendly_team[actor_team_index] = apply_effect(actor, "shield", int(skill.get("duration", 0)), shield_amount, true)
			friendly_team[actor_team_index] = apply_effect(friendly_team[actor_team_index], "def_up", int(skill.get("duration", 0)), float(skill.get("defense_modifier", 0.0)), true, float(skill.get("defense_modifier", 0.0)))
			events.append({"type": "shield_created", "target_id": str(actor.get("id", "")), "amount": shield_amount})
			events.append({"type": "effect_applied", "target_id": str(actor.get("id", "")), "effect": "def_up", "duration": int(skill.get("duration", 0))})
		"heal_cleanse":
			var target_index: int = int(command.get("friendly_target_index", -1))
			if target_index < 0 or target_index >= friendly_team.size() or int(friendly_team[target_index]["hp"]) <= 0:
				return {"allies": updated_allies, "enemies": updated_enemies, "events": events}
			actor["energy"] = clampi(int(actor.get("energy", STARTING_ENERGY)) - skill_cost, 0, MAX_ENERGY)
			friendly_team[actor_team_index] = actor
			var target: Dictionary = friendly_team[target_index]
			var heal_amount: int = roundi(effective_stat(actor, "atk") * float(skill.get("multiplier", 1.0)))
			var healed: int = _heal_unit(target, heal_amount)
			var cleansed: String = _cleanse_one_unit(target)
			friendly_team[target_index] = target
			events.append({"type": "healed", "target_id": str(target.get("id", "")), "amount": healed, "hp_after": target["hp"]})
			if not cleansed.is_empty():
				events.append({"type": "effect_removed", "target_id": str(target.get("id", "")), "effect": cleansed})
		"team_shield":
			actor["energy"] = clampi(int(actor.get("energy", STARTING_ENERGY)) - skill_cost, 0, MAX_ENERGY)
			friendly_team[actor_team_index] = actor
			for index: int in range(friendly_team.size()):
				var member: Dictionary = friendly_team[index]
				if int(member["hp"]) <= 0:
					continue
				var shield_amount: int = roundi(float(member.get("max_hp", 0)) * float(skill.get("shield_percent", 0.0)))
				friendly_team[index] = apply_effect(member, "shield", int(skill.get("duration", 0)), shield_amount, index == actor_team_index)
				events.append({"type": "shield_created", "target_id": str(member.get("id", "")), "amount": shield_amount})
		_:
			return {"allies": updated_allies, "enemies": updated_enemies, "events": events}

	return {"allies": updated_allies, "enemies": updated_enemies, "events": events}

static func _heal_unit(unit: Dictionary, amount: int) -> int:
	var previous_hp: int = int(unit["hp"])
	unit["hp"] = mini(int(unit["max_hp"]), previous_hp + amount)
	return int(unit["hp"]) - previous_hp

static func _cleanse_one_unit(unit: Dictionary) -> String:
	var effects: Array = unit.get("effects", [])
	for effect_type: String in ["stun", "freeze", "bind", "burn", "atk_down", "def_down"]:
		for index: int in range(effects.size()):
			var eff: Dictionary = effects[index]
			if str(eff.get("type", "")) == effect_type:
				effects.remove_at(index)
				unit["effects"] = effects
				return effect_type
	return ""

## AI chọn kỹ năng theo Master Context:
## Energy >= 80 -> Skill 2; Energy >= 40 -> Skill 1; Ngược lại -> Đánh thường (0).
static func choose_auto_action(actor: Dictionary, allow_skill_2: bool = true) -> int:
	if _unit_has_effect(actor, "stun") or _unit_has_effect(actor, "freeze"):
		return -1
	var current_energy: int = int(actor.get("energy", STARTING_ENERGY))
	var skills: Array = actor.get("skills", [])
	if allow_skill_2 and skills.size() >= 2:
		var skill_2: Dictionary = skills[1]
		var cost_2: int = int(skill_2.get("cost", skill_2.get("energy_cost", SKILL_2_ENERGY_COST)))
		if current_energy >= cost_2:
			return 2
	if skills.size() >= 1:
		var skill_1: Dictionary = skills[0]
		var cost_1: int = int(skill_1.get("cost", skill_1.get("energy_cost", SKILL_1_ENERGY_COST)))
		if current_energy >= cost_1:
			return 1
	return 0

static func choose_enemy_skill(actor: Dictionary, friendly_team: Array, opposing_team: Array) -> int:
	if _unit_has_effect(actor, "stun") or _unit_has_effect(actor, "freeze"):
		return -1
	var skills: Array = actor.get("skills", [])
	var current_energy: int = int(actor.get("energy", STARTING_ENERGY))
	# Ưu tiên kiểm tra Skill 2 (80 Energy) trước, sau đó đến Skill 1 (40 Energy)
	for index: int in range(skills.size() - 1, -1, -1):
		var skill: Dictionary = skills[index]
		var cost: int = int(skill.get("cost", skill.get("energy_cost", SKILL_2_ENERGY_COST if index == 1 else SKILL_1_ENERGY_COST)))
		if current_energy >= cost and _enemy_skill_is_useful(skill, actor, friendly_team, opposing_team):
			return index
	return -1

## AI chọn mục tiêu theo Vai trò (Master Context Section 4):
## - Attacker / Bruiser: Ưu tiên địch có HP thấp nhất.
## - Tank: Ưu tiên địch có ATK cao nhất.
## - Controller: Ưu tiên địch có vai trò Support / Healer (hoặc SPD cao nhất nếu không có).
static func preferred_target_index(actor: Dictionary, targets: Array) -> int:
	# Kiểm tra nếu có mục tiêu đang Taunt
	for index: int in range(targets.size()):
		var t: Dictionary = targets[index]
		if int(t.get("hp", 0)) > 0 and _unit_has_effect(t, "taunt"):
			return index

	var chosen: int = -1
	var best_value: float = -INF
	var role: String = str(actor.get("role", "Attacker"))

	for index: int in range(targets.size()):
		var target: Dictionary = targets[index]
		var current_hp: int = int(target.get("hp", 0))
		if current_hp <= 0:
			continue
		var value: float = 0.0
		match role:
			"Tank":
				value = effective_stat(target, "atk")
			"Controller":
				var target_role: String = str(target.get("role", ""))
				var role_priority: float = 100000.0 if target_role in ["Healer", "Support"] else 0.0
				value = role_priority + effective_stat(target, "spd")
			"Attacker", "Bruiser", _:
				# Ưu tiên mục tiêu có lượng máu thấp nhất / tỷ lệ máu thấp nhất
				var max_hp: float = maxf(1.0, float(target.get("max_hp", current_hp)))
				var missing_ratio: float = 1.0 - (float(current_hp) / max_hp)
				value = missing_ratio * 1000.0 - float(current_hp) * 0.001

		if value > best_value:
			best_value = value
			chosen = index
	return chosen

static func heal_target_index(team: Array, health_threshold: float = 0.5) -> int:
	var chosen: int = -1
	var lowest_ratio: float = health_threshold
	for index: int in range(team.size()):
		var member: Dictionary = team[index]
		if int(member.get("hp", 0)) <= 0:
			continue
		var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
		var ratio: float = float(member["hp"]) / float(max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			chosen = index
	return chosen

static func _enemy_skill_is_useful(skill: Dictionary, actor: Dictionary, friendly_team: Array, opposing_team: Array) -> bool:
	var effect_name: String = str(skill.get("effect", skill.get("effect_type", "")))
	# Healers chỉ dùng kỹ năng hồi máu khi có đồng minh < 50% HP (Master Context)
	match effect_name:
		"heal_cleanse", "team_heal_regen":
			return heal_target_index(friendly_team, 0.5) >= 0
		"team_shield":
			for member_var: Variant in friendly_team:
				var member: Dictionary = member_var
				if int(member.get("hp", 0)) > 0 and int(member.get("shield", 0)) <= 0:
					return true
			return false
		"self_shield_defense":
			return int(actor.get("shield", 0)) <= 0 and not _unit_has_effect(actor, "def_up")
		"damage", "damage_bind":
			return _has_living_unit(opposing_team)
	return false

static func _unit_has_effect(unit: Dictionary, effect_type: String) -> bool:
	var effects: Array = unit.get("effects", [])
	for effect_var: Variant in effects:
		if typeof(effect_var) == TYPE_DICTIONARY and str((effect_var as Dictionary).get("type", "")) == effect_type:
			return true
	return false

static func _has_living_unit(team: Array) -> bool:
	for member_var: Variant in team:
		if typeof(member_var) == TYPE_DICTIONARY and int((member_var as Dictionary).get("hp", 0)) > 0:
			return true
	return false

static func resolve_end_turn_command(allies: Array, enemies: Array, actor_index: int, used_skill: bool, trigger_passives: bool = true) -> Dictionary:
	var updated_allies: Array = allies.duplicate(true)
	var updated_enemies: Array = enemies.duplicate(true)
	if actor_index < 0 or actor_index >= updated_allies.size() + updated_enemies.size():
		return {"allies": updated_allies, "enemies": updated_enemies, "events": []}
	var actor_is_enemy: bool = actor_index >= updated_allies.size()
	var actor_team_index: int = actor_index - updated_allies.size() if actor_is_enemy else actor_index
	var friendly_team: Array = updated_enemies if actor_is_enemy else updated_allies
	var actor: Dictionary = friendly_team[actor_team_index]
	var events: Array[Dictionary] = []

	if trigger_passives and used_skill and str(actor.get("passive", "")) == "tidal_rhythm":
		var injured_idx: int = _most_injured_unit_index(friendly_team)
		if injured_idx >= 0:
			var heal_target: Dictionary = friendly_team[injured_idx]
			var heal_amount: int = roundi(float(heal_target.get("max_hp", 0)) * 0.05)
			var healed: int = _heal_unit(heal_target, heal_amount)
			events.append({"type": "passive_heal", "passive": "tidal_rhythm", "target_id": str(heal_target.get("id", "")), "target_name": str(heal_target.get("name", "")), "amount": healed})

	if trigger_passives and str(actor.get("passive", "")) == "forest_vitality":
		for member_index: int in range(friendly_team.size()):
			var member: Dictionary = friendly_team[member_index]
			var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
			if int(member.get("hp", 0)) > 0 and float(member["hp"]) / float(max_hp) < 0.3:
				var heal_amount: int = roundi(float(max_hp) * 0.3)
				var healed: int = _heal_unit(member, heal_amount)
				events.append({"type": "passive_heal", "passive": "forest_vitality", "target_id": str(member.get("id", "")), "target_name": str(member.get("name", "")), "amount": healed})
				break

	actor = friendly_team[actor_team_index]
	var effects: Array = actor.get("effects", [])
	for effect_index: int in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[effect_index]
		if bool(effect.get("skip_first_end", false)):
			effect["skip_first_end"] = false
			continue
		if str(effect.get("type", "")) == "burn" and int(actor.get("hp", 0)) > 0:
			var burn_damage: int = maxi(1, roundi(float(actor.get("max_hp", 1)) * 0.05))
			actor["hp"] = maxi(0, int(actor["hp"]) - burn_damage)
			events.append({"type": "burn_damage", "target_id": str(actor.get("id", "")), "target_name": str(actor.get("name", "")), "amount": burn_damage})
		elif str(effect.get("type", "")) == "regen" and int(actor.get("hp", 0)) > 0:
			var healed: int = _heal_unit(actor, roundi(float(effect.get("amount", 0.0))))
			events.append({"type": "regen_heal", "target_id": str(actor.get("id", "")), "target_name": str(actor.get("name", "")), "amount": healed})
		effect["turns"] = int(effect.get("turns", 0)) - 1
		if int(effect["turns"]) <= 0:
			if str(effect.get("type", "")) == "shield":
				actor["shield"] = 0
			events.append({"type": "effect_expired", "target_id": str(actor.get("id", "")), "effect": str(effect.get("type", ""))})
			effects.remove_at(effect_index)
	actor["effects"] = effects
	friendly_team[actor_team_index] = actor
	return {"allies": updated_allies, "enemies": updated_enemies, "events": events}

static func _most_injured_unit_index(team: Array) -> int:
	var chosen: int = -1
	var lowest_ratio: float = 2.0
	for index: int in range(team.size()):
		var unit: Dictionary = team[index]
		if int(unit.get("hp", 0)) <= 0:
			continue
		var max_hp: int = maxi(1, int(unit.get("max_hp", 1)))
		var ratio: float = float(unit["hp"]) / float(max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			chosen = index
	return chosen

static func apply_effect(unit: Dictionary, effect_type: String, duration: int, amount: float, skip_first_end: bool = false, modifier_override: float = 0.0) -> Dictionary:
	var updated: Dictionary = unit.duplicate(true)
	var new_effect := {"type": effect_type, "turns": duration, "amount": amount, "stat": "", "modifier": 0.0, "skip_first_end": skip_first_end}
	match effect_type:
		"atk_up":
			new_effect["stat"] = "atk"
			new_effect["modifier"] = 0.25
		"atk_down":
			new_effect["stat"] = "atk"
			new_effect["modifier"] = -0.25
		"def_up":
			new_effect["stat"] = "def"
			new_effect["modifier"] = 0.25
		"def_down":
			new_effect["stat"] = "def"
			new_effect["modifier"] = -0.25
	if modifier_override != 0.0:
		new_effect["modifier"] = modifier_override
	if effect_type == "shield":
		updated["shield"] = roundi(amount)
	var effects: Array = updated.get("effects", []).duplicate(true)
	for index: int in range(effects.size()):
		var existing_eff: Dictionary = effects[index]
		if str(existing_eff.get("type", "")) == effect_type:
			effects[index] = new_effect
			updated["effects"] = effects
			return updated
	effects.append(new_effect)
	updated["effects"] = effects
	return updated

## Thanh hành động (Action Bar 1000 điểm dựa trên SPD).
## Khi đạt >= 1000 điểm sẽ kích hoạt lượt đi và trừ 1000 điểm.
static func advance_action_gauges(allies: Array, enemies: Array, current_gauges: Array) -> Dictionary:
	var updated_gauges: Array[int] = []
	var total_units: int = allies.size() + enemies.size()
	for i: int in range(total_units):
		var initial_val: int = int(current_gauges[i]) if i < current_gauges.size() else 0
		updated_gauges.append(initial_val)

	# Nếu chưa có ai >= 1000 điểm, cộng SPD vào thanh Action Bar của các đơn vị còn sống
	var chosen: int = _pick_ready_actor(allies, enemies, updated_gauges)
	if chosen < 0:
		for index: int in range(allies.size()):
			var ally: Dictionary = allies[index]
			if int(ally.get("hp", 0)) > 0:
				updated_gauges[index] += maxi(1, roundi(effective_stat(ally, "spd")))
		for index: int in range(enemies.size()):
			var enemy: Dictionary = enemies[index]
			if int(enemy.get("hp", 0)) > 0:
				var gauge_index: int = allies.size() + index
				updated_gauges[gauge_index] += maxi(1, roundi(effective_stat(enemy, "spd")))
		chosen = _pick_ready_actor(allies, enemies, updated_gauges)

	if chosen >= 0:
		updated_gauges[chosen] -= ACTION_BAR_THRESHOLD
	return {"actor_index": chosen, "gauges": updated_gauges}

static func _pick_ready_actor(allies: Array, enemies: Array, gauges: Array[int]) -> int:
	var chosen: int = -1
	var largest_gauge: int = ACTION_BAR_THRESHOLD - 1
	for index: int in range(gauges.size()):
		var unit: Dictionary = allies[index] if index < allies.size() else enemies[index - allies.size()]
		var alive: bool = int(unit.get("hp", 0)) > 0
		if alive and gauges[index] >= ACTION_BAR_THRESHOLD and gauges[index] > largest_gauge:
			chosen = index
			largest_gauge = gauges[index]
	return chosen
