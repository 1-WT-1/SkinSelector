extends Reference

static func find_hull(node: Node) -> Node:
	if not node:
		return null
	var direct = node.find_node("Hull", true, false)
	if direct and (direct.get("hullCustomPaintFile") != null or direct.has_method("applyShipConfigSkin")):
		return direct
	return _search_hull_recursive(node)

static func _search_hull_recursive(node: Node) -> Node:
	for child in node.get_children():
		if child.get("hullCustomPaintFile") != null or child.has_method("applyShipConfigSkin"):
			return child
		var nested = _search_hull_recursive(child)
		if nested:
			return nested
	return null

static func get_model_from_paint_file(paint_file: String) -> String:
	var filename = paint_file.get_file()
	if filename.begins_with("custom-") and filename.ends_with(".png"):
		return filename.trim_prefix("custom-").trim_suffix(".png").to_lower()
	return ""

static func get_hull_model(ship: Node, paint_file: String = "") -> String:
	var model = get_model_from_paint_file(paint_file)
	if model.empty() and ship and "model" in ship and ship.model:
		model = String(ship.model).to_lower()
	return model

static func resolve_ship_info(ship: Node) -> Dictionary:
	var info = {
		"model": "",
		"legacy_file": ""
	}
	if not ship:
		return info
	var hull = find_hull(ship)
	if hull:
		var paint_file = hull.get("hullCustomPaintFile")
		if paint_file:
			info.legacy_file = String(paint_file)
	info.model = get_hull_model(ship, info.legacy_file)
	return info

static func refresh_ship_hulls(node: Node) -> void:
	if not node:
		return
	if node.has_method("applyShipConfigSkin"):
		node.applyShipConfigSkin()
	for child in node.get_children():
		refresh_ship_hulls(child)

static func set_ship_skin(target_ship: Node, skin_val: String, update_player_save: bool = false) -> void:
	if target_ship and "shipConfig" in target_ship and target_ship.shipConfig:
		target_ship.shipConfig["customSkin"] = skin_val
	if update_player_save:
		var cfg = CurrentGame.getPlayerShipConfig()
		if cfg and "config" in cfg:
			cfg.config["customSkin"] = skin_val
			CurrentGame.setPlayerShipConfig(cfg.config)
	refresh_ship_hulls(target_ship)

static func get_skins_dir(model: String) -> String:
	if model.empty():
		return ""
	return "user://skins".plus_file(model.to_lower())

static func ensure_skins_dir(model: String) -> void:
	var dir = get_skins_dir(model)
	if dir != "":
		Directory.new().make_dir_recursive(dir)

static func get_available_skins(model: String) -> Array:
	if model.empty():
		return []
	ensure_skins_dir(model)
	var skins = []
	var dir = Directory.new()
	var path = get_skins_dir(model)
	
	var err = dir.open(path)
	if err == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
				skins.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		Debug.l("[SkinSelector] Failed to open skins directory %s: error %d" % [path, err])
	
	skins.sort()
	return skins

static func load_texture_from_path(path: String) -> Texture:
	if not path or path.empty():
		return null
	if not File.new().file_exists(path):
		Debug.l("[SkinSelector] Texture file not found: %s" % path)
		return null
	
	if ModLoader and ModLoader._savedObjects.size() > 0:
		var pointers: HevLibPointers = ModLoader._savedObjects[0]
		if pointers and pointers.FileAccess:
			return pointers.FileAccess.__load_png(path)
	
	return null

static func is_default_skin(skin_val) -> bool:
	return skin_val == null or skin_val == "" or skin_val == "none"

static func load_skin_texture(model: String, filename: String, legacy_path: String = "") -> Texture:
	if is_default_skin(filename):
		return null
	if filename == "<Legacy>":
		return load_texture_from_path(legacy_path)
	if model.empty():
		Debug.l("[SkinSelector] Cannot load skin '%s': unknown ship model" % filename)
		return null
	return load_texture_from_path(get_skins_dir(model).plus_file(filename))

static func open_skins_folder(model: String) -> void:
	if model.empty():
		Debug.l("[SkinSelector] Cannot open skins folder: unknown ship model")
		return
	ensure_skins_dir(model)
	var global_path = ProjectSettings.globalize_path(get_skins_dir(model))
	OS.shell_open(global_path)
