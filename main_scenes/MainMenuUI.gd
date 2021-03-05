extends Node2D

func _ready():
	$Buttons/Start.grab_focus();
	$Buttons/Start.connect("pressed", get_tree(), "change_scene_to", [Globals.game_main_scene]);
	$Buttons/Quit.connect("pressed", get_tree(), "quit");

