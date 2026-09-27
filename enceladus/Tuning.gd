extends "res://enceladus/Tuning.gd"

onready var skinSelectorRow = preload("res://SkinSelector/ui/SkinSelectorRow.tscn")

func fillTuneableSystems():
	.fillTuneableSystems()
	
	if not itemsNodePath:
		return
	var node = get_node(itemsNodePath)
	var player_ship = CurrentGame.getPlayerShip()
	if node and player_ship:
		var row = skinSelectorRow.instance()
		node.add_child(row)
		row.setup(player_ship, self)
