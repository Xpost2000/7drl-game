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
		# var colors = [Color.red, Color.green, Color.blue];
		# for i in range(300):
		# 	draw_string(game_font, Vector2(0, i * FONT_HEIGHT), "Hello world", colors[i%3]);
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
						var cell_id;
						var cell_symbol;
						var cell_color;
						# if chunk.is_cell_visible(x, y):
						draw_string(game_font, Vector2((x + (chunk_x * world.CHUNK_MAX_SIZE))*(FONT_HEIGHT/2),
						 (y + (chunk_y * world.CHUNK_MAX_SIZE))*FONT_HEIGHT), "#", Color.blue);
						# tilemap.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), chunk.get_cell(x, y));
						# _fog_of_war.set_cell(x + (chunk_x * CHUNK_MAX_SIZE), y + (chunk_y * CHUNK_MAX_SIZE), 1 - chunk.is_cell_visible(x, y));
						# paint_chunk_to_tilemap(get_child(neighbor_index), world_chunks[offset_position.y][offset_position.x], offset_position.x, offset_position.y);
	if entities:
		for entity in entities.entities:
			draw_string(game_font, Vector2(entity.position.x*(FONT_HEIGHT/2), entity.position.y*FONT_HEIGHT), "@", Color.red);
	pass;

func _process(_delta):
	pass;
