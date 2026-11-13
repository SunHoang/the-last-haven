extends Resource
class_name LootDropData

@export var item_id: StringName
@export var display_name: String
@export_range(0.0, 1.0) var chance := 1.0
@export_range(1, 99) var quantity_min := 1
@export_range(1, 99) var quantity_max := 1
