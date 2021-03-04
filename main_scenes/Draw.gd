# This is for manually drawing things...
# This part is kind of scuffed.

# This is probably debug related stuff anyways.
extends Node2D

var game_font;
const FONT_HEIGHT = 16;
func _init():
	game_font = DynamicFont.new();
	game_font.font_data = load("res://resources/DinaRemasterCollection.ttf");
	game_font.size = FONT_HEIGHT;

func _draw():
	var colors = [Color.red, Color.green, Color.blue];
	for i in range(300):
		draw_string(game_font, Vector2(0, i * FONT_HEIGHT), "Hello world", colors[i%3]);
	pass;

func _process(_delta):
	pass;