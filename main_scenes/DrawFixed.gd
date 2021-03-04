extends Node2D
# This is for manually drawing things...
# This part is kind of scuffed.

# This is probably debug related stuff anyways.
var game_font;
const FONT_HEIGHT = 32;
func _init():
	game_font = DynamicFont.new();
	game_font.font_data = load("res://resources/DinaRemasterCollection.ttf");
	game_font.size = FONT_HEIGHT;

func _draw():
	# draw_string(game_font, Vector2(0, FONT_HEIGHT), "Hello world");
	pass;

func _process(_delta):
	pass;