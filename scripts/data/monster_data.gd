extends Resource
class_name MonsterData

@export_group("Identity & Classification")
@export var def_id: String = "core:species:mossling"
@export var display_name: String = ""
@export_enum("Nature", "Earth", "Electric", "Water", "Fire", "Wind", "Light", "Dark", "Ice", "Aether") var element: String = "Nature"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical") var rarity: String = "Common"
@export_enum("Tank", "Bruiser", "Attacker", "Speedster", "Healer", "Support", "Controller") var role: String = "Attacker"
@export var profession: String = ""

@export_group("Base Core Stats")
@export_range(1, 999999) var base_hp: int = 100
@export_range(1, 999999) var base_atk: int = 10
@export_range(1, 999999) var base_def: int = 10
@export_range(1, 999999) var base_spd: int = 100

@export_group("Active Skills")
@export var skill_1: SkillData
@export_range(0, 100) var skill_1_energy_cost: int = 40
@export var skill_2: SkillData
@export_range(0, 100) var skill_2_energy_cost: int = 80

@export_group("Passives (Combat & Utility)")
@export var combat_passive_id: String = ""
@export var combat_passive_name: String = ""
@export_multiline var combat_passive_description: String = ""

@export var utility_passive_id: String = ""
@export var utility_passive_name: String = ""
@export var utility_building: String = ""
@export_range(0.0, 500.0, 1.0) var utility_bonus_percent: float = 0.0
@export var utility_bonus_resource: String = ""

