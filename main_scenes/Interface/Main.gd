extends Control

onready var _message_log = $Messages;

onready var _other_health_bars = $Ingame/Healthbars/Others;
onready var _self_health_bar = $Ingame/Healthbars/SelfHealth;

const health_card_prefab = preload("res://main_scenes/Interface/HealthDisplayBar.tscn");

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

func report_player_health(entity):
	_self_health_bar.update_from(entity);

func report_survivor_stats(survivors_list):
	# The first slot is occupied by the player survivor so we omit that.
	for card in _other_health_bars.get_children():
		card.hide();
	for survivor_index in range(1, len(survivors_list)):
		var card = _other_health_bars.get_child(survivor_index-1);
		card.update_from(survivors_list[survivor_index]);
		card.show();

func report_inventory(inventory_list):
	# dummy
	var entity = inventory_list;
	inventory_list = inventory_list.inventory;
	var inventory_item_list = $Ingame.get_node("InventoryDisplay/InventoryContents");

	for child in inventory_item_list.get_children():
		inventory_item_list.remove_child(child);
	
	for item_index in len(inventory_list):
		var item = inventory_list[item_index];
		var string_display = Globals.alphabet[item_index] + ". " + item.as_string();
		if item == entity.currently_equipped_weapon:
			string_display += "(EQ)";
		var new_label = Label.new();
		new_label.text = string_display;
		inventory_item_list.add_child(new_label);

func _ready():
	set_state(INGAME_STATE);
	$Death/Holder/OptionsLayout/Restart.connect("pressed", get_tree(), "reload_current_scene");
	$Death/Holder/OptionsLayout/Quit.connect("pressed", get_tree(), "change_scene_to", [Globals.main_menu_scene]);
	$Death/Holder/OptionsLayout/Exit.connect("pressed", get_tree(), "quit");
