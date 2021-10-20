extends PopupPanel


signal saved_game()
signal loaded_game()

const SAVES_PATH := "user://"
const SAVE_ENDING := ".save"
const SAVE_TEXT := "%02d/%02d/%02d %02d:%02d:%02d"

var _cur_slot := -1
var _save_files := []

onready var buttons = {
	"save_bnt" : $HBoxContainer/Buttons/Save,
	"load_bnt" : $HBoxContainer/Buttons/Load,
	"delete_bnt" : $HBoxContainer/Buttons/Delete,
	"delete_all_bnt" : $HBoxContainer/Buttons/DeleteAll
}
onready var _slots := $HBoxContainer/ScrollContainer/Slots


func _ready() -> void:
	_save_files = list_files_in_save_directory()
	# Invert the save file array to sort by descending date order
	_save_files.invert()
	for file_name in _save_files:
		create_save_slot_button(file_name)

	update_buttons(null, null, null,_save_files.size() == 0)

# Internal: Returns a list of all files in the save directory
#
# Example
#	list_files_in_save_directory()
#		=> ["user://1634645541.save", ...]
#
# Return Array
func list_files_in_save_directory():
	var list = []
	var dir := Directory.new()
	if dir.open(SAVES_PATH) == OK and dir.list_dir_begin(true) == OK:
		var file_name := dir.get_next()
		while not file_name == "":
			if not dir.current_is_dir() and file_name.ends_with(SAVE_ENDING):
				list.append(SAVES_PATH + file_name)

			file_name = dir.get_next()

	return list

# Sets the disabled for the save/load screen buttons
#
# save_bnt = Determince if the save button is disabled or not. (Bool)
# load_bnt = Determince if the load button is disabled or not. (Bool)
# delete_bnt = Determince if the delete button is disabled or not. (Bool)
# delete_all_bnt = Determince if the delete all button is disabled or not. (Bool)
#
# Example
#	update_buttons(null, true, false, true)
#
# Returns Nothing
func update_buttons(save_bnt = null, load_bnt = null, delete_bnt = null, delete_all_bnt = null):
	var bnt_dict = {
		"save_bnt" : save_bnt,
		"load_bnt" : load_bnt,
		"delete_bnt" : delete_bnt,
		"delete_all_bnt" : delete_all_bnt
	}

	for bnt in buttons:
		if bnt_dict[bnt] != null:
			buttons[bnt].disabled = bnt_dict[bnt]

# Internal: Generates the save slot name from the provided file name
#
# file_name = Contains the file name thats used to generate the slot name
#
# Example
#	create_slot_name_using_file_name("user://1634645541.save")
#		=> 2021/10/19 12:12:21
#
# Returns String
func create_slot_name_using_file_name(file_name:String) -> String:
	file_name = file_name.replace(SAVES_PATH, "").replace(SAVE_ENDING, "")
	var date := OS.get_datetime_from_unix_time(int(file_name))
	return SAVE_TEXT % [date.year, date.month, date.day, date.hour, date.minute, date.second]

# Internal: Creates a save slot button usring the provided save file name
#
# file_name = Contains the file name thats used to generate the save slot button
#
# Example
#	create_save_slot_button("user://1634645541.save")
#
# Returns Nothing
func create_save_slot_button(file_name:String):
	var b := Button.new()
	_slots.add_child(b)
	b.text = create_slot_name_using_file_name(file_name)
	b.toggle_mode = true
	b.group = $HBoxContainer/ScrollContainer/Slots/NewSlot.group
	if b.connect("pressed", self, "_on_save_slot_pressed", [b]) != OK:
		push_error("Save slot failed to connect")

# Public: Called when the new save slot button is pressed
func _on_new_slot_pressed() -> void:
	_cur_slot = 0
	update_buttons(false, true, true)
# Public: Setup the available buttons when save slot is pressed
#
# button = Contain's the button object that was pressed
#
# Example
#	_on_save_slot_pressed(button.tscn)
#
# Returns Nothing
func _on_save_slot_pressed(button: Button) -> void:
	_cur_slot = button.get_index()
	update_buttons(false, false, false)

# Internal: Creates a file name based on OS time
#
# Example
#	create_file_name()
#		=> "user://1634645541.save"
#
# Returns String
func create_file_name():
	var file_name = SAVES_PATH + str(OS.get_unix_time())
	# Ensures that same-second saves have different paths
	while file_name + SAVE_ENDING in SAVES_PATH:
		file_name += "A"
	return file_name + SAVE_ENDING

# Internal: Calls for a save slot to be created and added to Scroll lise
#
# file_name = Contains the save file path
#
# Example
#	create_save_slot("user://1634645541.save")
#
# Returns Nothing
func create_save_slot(file_name:String):
	_save_files.push_front(file_name)
	create_save_slot_button(file_name)
	# Moves the new save to the front, after the New Slot button
	_slots.move_child(_slots.get_child(_slots.get_child_count()-1), 1)

# Internal: Updates the name and position of the selected save slot
#
# file_name = Contains the save file path
#
# Example
#	update_save_slot("user://1634645541.save")
#
# Returns Nothing
func update_save_slot(file_name:String):
	var dir := Directory.new()
	# warning-ignore:return_value_discarded
	if dir.remove(_save_files[_cur_slot-1]) != OK:
		push_error("Failed to remove save file")
	_save_files.remove(_cur_slot-1)
	_save_files.push_front(file_name)
	_slots.get_child(_cur_slot).text = create_slot_name_using_file_name(file_name)
	# Moves the save to the front, after the New Slot button
	_slots.move_child(_slots.get_child(_cur_slot), 1)
	_cur_slot = 1

# Public: Called when save button is pressed to ether create or update a save slot
func _on_save_pressed() -> void:
	update_buttons(null, null, null, false)
	var file_name = create_file_name()
	var file := File.new()

	if file.open(file_name, File.WRITE) != OK:
		push_error("Failed to open save file")

	file.close()

	if _cur_slot == 0:
		create_save_slot(file_name)
	else:
		update_save_slot(file_name)

	emit_signal("saved_game", file_name)

# Public: Called when the load button is pressed to read in the select save file.
func _on_load_pressed() -> void:
	var file = File.new()
	file.open(_save_files[_cur_slot-1], File.READ)
	file.close()
	emit_signal("loaded_game", _save_files[_cur_slot-1])

# Called when the delete button is pressed to delete the selected save slot.
func _on_delete_pressed() -> void:
	var dir := Directory.new()

	if dir.remove(_save_files[_cur_slot-1]) != OK:
		push_error("Failed to remove save file")

	_slots.get_child(_cur_slot).free()
	_save_files.remove(_cur_slot-1)
	update_buttons(true, true, true, _save_files.size() == 0)
	_cur_slot = -1

# Public: Deleted all files in the save directory
func _on_delete_all_pressed() -> void:
	var dir := Directory.new()
	for file_name in list_files_in_save_directory():
		if dir.remove(file_name) != OK:
			push_error("Failed to remove file")

	for child in _slots.get_children():
		if not child.name == "NewSlot":
			child.free()
	if not _cur_slot == 0:
		update_buttons(true, true, true)

	update_buttons(null, null, null, true)
