extends Control

onready var _message_log = $Messages;
const UNDEFINED = -999;
const DEATH_STATE = 0;
const INGAME_STATE = 1;
const PAUSE_STATE = 2;

onready var states = {
	DEATH_STATE: $Death,
	INGAME_STATE: $Ingame,
	PAUSE_STATE: $Pause,
};
onready var state = UNDEFINED setget set_state;
onready var previous_state = INGAME_STATE;
func set_state(new_state):
	if new_state != state:
		previous_state = state;
		var target = states[new_state];
		state = new_state;
		for child in get_children():
			if child != _message_log and child != target:
				child.hide();
		target.show()

func message(string):
	_message_log.push_message(string);

func report_inventory(inventory_list):
	var inventory_item_list = $Ingame.get_node("InventoryDisplay/InventoryContents");

	for child in inventory_item_list.get_children():
		inventory_item_list.remove_child(child);
	
	for item_index in len(inventory_list):
		var item = inventory_list[item_index].as_string();
		var string_display = Globals.alphabet[item_index] + ". " + item;
		var new_label = Label.new();
		new_label.text = string_display;
		inventory_item_list.add_child(new_label);

func _ready():
	set_state(INGAME_STATE);
	$Death/Holder/OptionsLayout/Restart.connect("pressed", get_tree(), "reload_current_scene");
	$Death/Holder/OptionsLayout/Quit.connect("pressed", get_tree(), "change_scene_to", [Globals.main_menu_scene]);
	$Death/Holder/OptionsLayout/Exit.connect("pressed", get_tree(), "quit");
