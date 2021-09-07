extends PopupPanel


signal saved_game()
signal loaded_game()

const _SAVES_PATH := "user://"
const _SAVE_ENDING := ".save"
const _SAVE_TEXT := "%02d/%02d/%02d %02d:%02d:%02d"

var _cur_slot := -1
var _save_files := []

onready var _save_button := $HBoxContainer/Buttons/Save
onready var _load_button := $HBoxContainer/Buttons/Load
onready var _delete_button := $HBoxContainer/Buttons/Delete
onready var _delete_all_button := $HBoxContainer/Buttons/DeleteAll
onready var _slots := $HBoxContainer/ScrollContainer/Slots


func _ready() -> void:
	# Iterate through the "user://" directory and get all save files
	var dir := Directory.new()
	if dir.open(_SAVES_PATH) == OK and dir.list_dir_begin(true) == OK:
		var file_name := dir.get_next()
		while not file_name == "":
			if not dir.current_is_dir() and file_name.ends_with(_SAVE_ENDING):
				_save_files.append(_SAVES_PATH + file_name)
			file_name = dir.get_next()
	# Invert the save file array to sort by descending date order
	_save_files.invert()
	for file_name in _save_files:
		_make_new_save_button(file_name)
	
	_delete_all_button.disabled = _save_files.size() == 0
	

func _file_name_to_slot_name(file_name) -> String:
	file_name = file_name.replace(_SAVES_PATH, "").replace(_SAVE_ENDING, "")
	var date := OS.get_datetime_from_unix_time(int(file_name))
	return _SAVE_TEXT % [date.year, date.month, date.day, date.hour, date.minute, date.second]


func _make_new_save_button(file_name):
	var b := Button.new()
	_slots.add_child(b)
	b.text = _file_name_to_slot_name(file_name)
	b.toggle_mode = true
	b.group = $HBoxContainer/ScrollContainer/Slots/NewSlot.group
# warning-ignore:return_value_discarded
	b.connect("pressed", self, "_on_save_slot_pressed", [b])


func _on_new_slot_pressed() -> void:
	_cur_slot = 0
	_save_button.disabled = false
	_load_button.disabled = true
	_delete_button.disabled = true


func _on_save_slot_pressed(b: Button) -> void:
	_cur_slot = b.get_index()
	_save_button.disabled = false
	_load_button.disabled = false
	_delete_button.disabled = false


func _on_save_pressed() -> void:
	_delete_all_button.disabled = false
	var file_name = _SAVES_PATH + str(OS.get_unix_time())
	# Ensures that same-second saves have different paths
	while file_name + _SAVE_ENDING in _SAVES_PATH:
		file_name += "A"
	file_name += _SAVE_ENDING
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open(file_name, File.WRITE)
	file.close()
	if _cur_slot == 0:
		_save_files.push_front(file_name)
		_make_new_save_button(file_name)
		# Moves the new save to the front, after the New Slot button
		_slots.move_child(_slots.get_child(_slots.get_child_count()-1), 1)
	else:
		var dir := Directory.new()
# warning-ignore:return_value_discarded
		dir.remove(_save_files[_cur_slot-1])
		_save_files.remove(_cur_slot-1)
		_save_files.push_front(file_name)
		_slots.get_child(_cur_slot).text = _file_name_to_slot_name(file_name)
		# Moves the save to the front, after the New Slot button
		_slots.move_child(_slots.get_child(_cur_slot), 1)
		_cur_slot = 1
	emit_signal("saved_game", file_name)


func _on_load_pressed() -> void:
	var file = File.new()
	file.open(_save_files[_cur_slot-1], File.READ)
	file.close()
	emit_signal("loaded_game", _save_files[_cur_slot-1])


# Called deferred
func _on_delete_pressed() -> void:
	var dir := Directory.new()
# warning-ignore:return_value_discarded
	dir.remove(_save_files[_cur_slot-1])
	_slots.get_child(_cur_slot).free()
	_save_files.remove(_cur_slot-1)
	_save_button.disabled = true
	_load_button.disabled = true
	_delete_button.disabled = true
	_delete_all_button.disabled = _save_files.size() == 0
	_cur_slot = -1
	

# Called deferred
func _on_delete_all_pressed() -> void:
	var dir := Directory.new()
	if dir.open(_SAVES_PATH) == OK and dir.list_dir_begin(true) == OK:
		var file_name := dir.get_next()
		while not file_name == "":
			if not dir.current_is_dir() and file_name.ends_with(_SAVE_ENDING):
# warning-ignore:return_value_discarded
				dir.remove(file_name)
			file_name = dir.get_next()
	for child in _slots.get_children():
		if not child.name == "NewSlot":
			child.free()
	if not _cur_slot == 0:
		_save_button.disabled = true
		_load_button.disabled = true
		_delete_button.disabled = true
	_delete_all_button.disabled = true
