extends "res://ships/Hull.gd"

const SkinManager = preload("res://SkinSelector/scripts/SkinManager.gd")

var _material_duplicated: bool = false

func _ready():
	applyShipConfigSkin()
	if ship and not ship.is_connected("setup", self, "applyShipConfigSkin"):
		ship.connect("setup", self, "applyShipConfigSkin")

func applyShipConfigSkin():
	if not (ship and "shipConfig" in ship and ship.shipConfig and "customSkin" in ship.shipConfig):
		return

	var model = SkinManager.get_hull_model(ship, hullCustomPaintFile)
	var tex = SkinManager.load_skin_texture(model, ship.shipConfig["customSkin"], hullCustomPaintFile)
	if tex:
		paintFromResource(tex)
	elif "customPaint" in ship and ship.customPaint:
		paintFromResource(ship.customPaint)
	else:
		clearSkin()

# Duplicate material once
func _ensure_unique_material() -> void:
	if material and not _material_duplicated:
		material = material.duplicate()
		_material_duplicated = true

func paintFromResource(texture):
	if material:
		_ensure_unique_material()
		material.set_shader_param("paintJobFactor", 1.0)
		material.set_shader_param("paintJob", texture)
		material.set_shader_param("frames", Vector2(hframes, vframes))

func clearSkin():
	if material:
		_ensure_unique_material()
		material.set_shader_param("paintJobFactor", 0.0)
		material.set_shader_param("paintJob", null)
