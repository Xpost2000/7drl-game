extends Node2D
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	$SwitchBack.connect("timeout", get_tree(), "change_scene_to", [Globals.main_menu_scene]);
	$CreditsTween.interpolate_property($Interface/ScrollContainer, "scroll_vertical",
	 0, $Interface/ScrollContainer/Content.rect_size.y, 4, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.0);
	$CreditsTween.start();


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
