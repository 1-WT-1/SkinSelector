extends VBoxContainer

const SkinManager = preload("res://SkinSelector/scripts/SkinManager.gd")

onready var nameBtn = $HBoxContainer/Label
onready var dropdown = $HBoxContainer/OptionButton
onready var refreshBtn = $HBoxContainer/RefreshButton
onready var folderBtn = $HBoxContainer/FolderButton

onready var hoverPreview = $HoverPreviewWindow
onready var previewTitle = $HoverPreviewWindow/VBox/PreviewTitle
onready var previewDim = $HoverPreviewWindow/VBox/PreviewDim
onready var previewTexture = $HoverPreviewWindow/VBox/PreviewTexture

var ship = null
var tuningScene = null
var currentModel: String = ""
var legacyFile: String = ""

var hoverTimer: Timer
var pendingSkinVal: String = ""
var lastHoveredIdx: int = -2

func setup(p_ship, p_tuning):
	ship = p_ship
	tuningScene = p_tuning
	var info = SkinManager.resolve_ship_info(ship)
	currentModel = info.model
	legacyFile = info.legacy_file
	if currentModel.empty():
		Debug.l("[SkinSelector] Warning: Could not resolve model key for ship '%s'" % [ship.getShipName() if ship and ship.has_method("getShipName") else str(ship)])
		folderBtn.disabled = true
	else:
		folderBtn.disabled = false
	refreshSkinsList()

func _ready():
	hoverPreview.visible = false
	_setup_hover_timer()
	_connect_signals()

func _exit_tree():
	if hoverTimer:
		hoverTimer.stop()
	hide_preview()

func _setup_hover_timer():
	hoverTimer = Timer.new()
	hoverTimer.one_shot = true
	hoverTimer.wait_time = 0.35
	hoverTimer.connect("timeout", self, "_on_hover_timeout")
	add_child(hoverTimer)

func _connect_signals():
	dropdown.connect("item_selected", self, "_on_skin_selected")
	dropdown.connect("mouse_entered", self, "_on_dropdown_mouse_entered")
	dropdown.connect("mouse_exited", self, "_on_dropdown_mouse_exited")
	dropdown.connect("focus_entered", self, "_on_dropdown_focus_entered")
	dropdown.connect("focus_exited", self, "_on_dropdown_focus_exited")
	
	refreshBtn.connect("pressed", self, "_on_refresh_pressed")
	folderBtn.connect("pressed", self, "_on_folder_pressed")
	nameBtn.connect("focus_entered", self, "_on_name_focus")
	
	var popup = dropdown.get_popup()
	if popup:
		popup.connect("popup_hide", self, "_on_popup_closed")
		popup.connect("id_focused", self, "_on_popup_id_focused")
		popup.connect("gui_input", self, "_on_popup_gui_input")

func _on_name_focus():
	dropdown.grab_focus()

func focus():
	dropdown.grab_focus()

func refreshSkinsList():
	dropdown.clear()
	dropdown.add_item(tr("SKIN_SELECTOR_DEFAULT"), 0)
	dropdown.set_item_metadata(0, "none")
	
	var legacy_file = legacyFile
	var next_id = 1
	var legacy_idx = -1
	if legacy_file != "" and File.new().file_exists(legacy_file):
		dropdown.add_item(tr("SKIN_SELECTOR_LEGACY") + " (" + legacy_file.get_file() + ")", next_id)
		dropdown.set_item_metadata(next_id, "<Legacy>")
		legacy_idx = next_id
		next_id += 1
	
	var available = SkinManager.get_available_skins(currentModel)
	for skin_file in available:
		dropdown.add_item(skin_file, next_id)
		dropdown.set_item_metadata(next_id, skin_file)
		next_id += 1
	
	var select_idx = _determine_selected_skin_index(legacy_idx)
	dropdown.select(select_idx)

func _determine_selected_skin_index(legacy_idx: int) -> int:
	var current_skin = ""
	if ship and "shipConfig" in ship and ship.shipConfig:
		current_skin = ship.shipConfig.get("customSkin", "")
	
	if current_skin == "" and legacy_idx != -1:
		return legacy_idx
	
	if current_skin != "" and current_skin != "none":
		for i in range(dropdown.get_item_count()):
			if dropdown.get_item_metadata(i) == current_skin:
				return i
	
	return 0

func _handle_hover_index(idx: int):
	if idx != lastHoveredIdx:
		lastHoveredIdx = idx
		hoverTimer.stop()
		if idx >= 0 and idx < dropdown.get_item_count():
			pendingSkinVal = dropdown.get_item_metadata(idx)
			hoverTimer.start()
		else:
			hide_preview()

func _on_popup_gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		var popup = dropdown.get_popup()
		if popup:
			_handle_hover_index(popup.get_current_index())

func _on_popup_id_focused(id: int):
	var idx = dropdown.get_item_index(id)
	_handle_hover_index(idx)

func _on_popup_closed():
	lastHoveredIdx = -2
	hoverTimer.stop()
	hide_preview()

func _on_dropdown_mouse_entered():
	var cur_idx = dropdown.get_selected()
	if cur_idx >= 0:
		pendingSkinVal = dropdown.get_item_metadata(cur_idx)
		hoverTimer.stop()
		hoverTimer.start()

func _on_dropdown_mouse_exited():
	var popup = dropdown.get_popup()
	if not (popup and popup.visible):
		hoverTimer.stop()
		hide_preview()

func _on_dropdown_focus_entered():
	var cur_idx = dropdown.get_selected()
	if cur_idx >= 0:
		pendingSkinVal = dropdown.get_item_metadata(cur_idx)
		hoverTimer.stop()
		hoverTimer.start()

func _on_dropdown_focus_exited():
	var popup = dropdown.get_popup()
	if not (popup and popup.visible):
		hoverTimer.stop()
		hide_preview()

func _on_hover_timeout():
	show_preview(pendingSkinVal)

func show_preview(skin_val: String):
	if SkinManager.is_default_skin(skin_val):
		hide_preview()
		return
	
	var data = _load_preview_data(skin_val)
	if not data.texture:
		hide_preview()
		return
	
	previewTexture.texture = data.texture
	previewTitle.text = data.title
	previewDim.text = data.dimensions
	
	var pop_size = Vector2(240, 340)
	var pop_pos = _calculate_preview_position(pop_size)
	hoverPreview.popup(Rect2(pop_pos, pop_size))

func _load_preview_data(skin_val: String) -> Dictionary:
	var legacy_file = legacyFile if skin_val == "<Legacy>" else ""
	var tex = SkinManager.load_skin_texture(currentModel, skin_val, legacy_file)
	if not tex:
		return {
			"texture": null,
			"title": "",
			"dimensions": ""
		}
	
	var title = legacy_file.get_file() if skin_val == "<Legacy>" else skin_val
	var sz = tex.get_size()
	return {
		"texture": tex,
		"title": title,
		"dimensions": "%d × %d px" % [int(sz.x), int(sz.y)]
	}

func _calculate_preview_position(pop_size: Vector2) -> Vector2:
	var vp_size = get_viewport_rect().size
	var pop_pos = Vector2.ZERO
	var popup = dropdown.get_popup()
	
	if popup and popup.visible:
		var pr = popup.get_global_rect()
		pop_pos.x = pr.position.x + pr.size.x + 8
		if pop_pos.x + pop_size.x > vp_size.x - 10:
			pop_pos.x = pr.position.x - pop_size.x - 8
		
		var target_y = pr.position.y
		var count = dropdown.get_item_count()
		if lastHoveredIdx >= 0 and count > 0:
			var item_h = pr.size.y / float(count)
			target_y = pr.position.y + (lastHoveredIdx * item_h) - (pop_size.y * 0.5)
		pop_pos.y = clamp(target_y, 10, vp_size.y - pop_size.y - 10)
	else:
		var dr = dropdown.get_global_rect()
		pop_pos.x = dr.position.x + dr.size.x + 8
		if pop_pos.x + pop_size.x > vp_size.x - 10:
			pop_pos.x = dr.position.x - pop_size.x - 8
		pop_pos.y = clamp(dr.position.y - (pop_size.y * 0.5), 10, vp_size.y - pop_size.y - 10)
	
	return pop_pos

func hide_preview():
	if hoverPreview and hoverPreview.visible:
		hoverPreview.hide()

func _on_skin_selected(idx: int):
	hoverTimer.stop()
	hide_preview()
	
	var skin_val = dropdown.get_item_metadata(idx)
	SkinManager.set_ship_skin(ship, skin_val, true)
	
	if tuningScene and "ship" in tuningScene and tuningScene.ship:
		SkinManager.set_ship_skin(tuningScene.ship, skin_val, false)

func _on_refresh_pressed():
	hide_preview()
	var info = SkinManager.resolve_ship_info(ship)
	currentModel = info.model
	legacyFile = info.legacy_file
	refreshSkinsList()

func _on_folder_pressed():
	SkinManager.open_skins_folder(currentModel)
