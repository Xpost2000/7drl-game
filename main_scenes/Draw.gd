# This allows "ASCII" mode for our tiles.
# Optimally we'd specify a mapping of ID to tile, but it's a bit annoying
# to do that and it's probably faster to just do it by hand...
extends Node2D

var game_font;
var world;
var entities;
onready var current_chunk_position = Vector2(0, 0);

const FONT_HEIGHT = 32;
func _init():
	game_font = DynamicFont.new();
	game_font.font_data = load("res://resources/DinaRemasterCollection.ttf");
	game_font.size = FONT_HEIGHT;

const neighbor_vectors = [Vector2(-1, 0),
						  Vector2(1, 0),
						  Vector2(0, 1),
						  Vector2(0, -1),
						  Vector2(1, 1),
						  Vector2(-1, 1),
						  Vector2(1, -1),
						  Vector2(-1, -1),
						  ];
func _draw():
	if world:
		var chunk_offsets = neighbor_vectors.duplicate();
		chunk_offsets.push_back(Vector2(0, 0));
		for neighbor_index in len(chunk_offsets):
			var neighbor_vector = chunk_offsets[neighbor_index];
			var offset_position = current_chunk_position + neighbor_vector;
			
			var chunk_x = offset_position.x;
			var chunk_y = offset_position.y;
			if world.in_bounds(offset_position):
				for y in range(world.CHUNK_MAX_SIZE):
					for x in range(world.CHUNK_MAX_SIZE):
						var tile_position = Vector2(x + (chunk_x * world.CHUNK_MAX_SIZE), (y) + (chunk_y * world.CHUNK_MAX_SIZE));
						var cell_id;
						var cell_symbol = "#" if world.is_solid_tile(tile_position) else ".";
						var light_value = world.is_cell_visible(tile_position);
						var cell_color = Color(1, 1, 1) if world.is_solid_tile(tile_position) else Color(0, 1, 0);

						if world.is_cell_visible(tile_position):
							draw_string(game_font, (tile_position+Vector2(0, 1)) * Vector2((FONT_HEIGHT/2), FONT_HEIGHT), cell_symbol, Color(cell_color * light_value));
	if entities:
		# stupid boldness.
		for entity in entities.entities:
			var tile_position = entity.position;
			if world.is_cell_visible(tile_position) == 1.0:
				draw_rect(Rect2(tile_position.x*(FONT_HEIGHT/2), tile_position.y*(FONT_HEIGHT), FONT_HEIGHT/2, FONT_HEIGHT), Color.black);
				draw_string(game_font, Vector2(tile_position.x*(FONT_HEIGHT/2), (1+tile_position.y)*FONT_HEIGHT), "@", Color.red);
				# draw_string(game_font, Vector2(tile_position.x*(FONT_HEIGHT/2)-0.25, (1+tile_position.y)*FONT_HEIGHT-0.25), "@", Color.red);
				# draw_string(game_font, Vector2(tile_position.x*(FONT_HEIGHT/2)+0.25, (1+tile_position.y)*FONT_HEIGHT-0.25), "@", Color.red);
	pass;

func _process(_delta):
	pass;
