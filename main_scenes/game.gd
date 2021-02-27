extends Node2D

# Just quickly seeing what would get me a decent organization structure.
# Doing a roguelike might require me to do a lot of perversion of the idiomatic godot way
# in which case I'm just writing a python roguelike engine and using godot as my driver...
# Which works I guess?
func _ready():
	pass;

func _physics_process(_delta):
	pass;

func player_movement_direction():
	if Input.is_action_just_pressed("ui_up"):
		return Vector2(0, -1);
	elif Input.is_action_just_pressed("ui_down"):
		return Vector2(0, 1);
	elif Input.is_action_just_pressed("ui_left"):
		return Vector2(-1, 0);
	elif Input.is_action_just_pressed("ui_right"):
		return Vector2(1, 0);

	return Vector2.ZERO;

onready var _world_map = $WorldMap;
const TILE_SIZE = 32;

# for now keep this in sync with tileset...
var _solid_cells_list = [8, 9];
func is_solid_tile(world_map, position) -> bool:
	var cell_at_position = world_map.get_cell(position.x, position.y);
	for cell in _solid_cells_list:
		if cell == cell_at_position:
			return true;
	return false;

func in_bounds_of(world_map, position) -> bool:
	var bounds_rect = world_map.get_used_rect();
	return (position.x >= bounds_rect.position.x && position.x < bounds_rect.size.x) && (position.y >= bounds_rect.position.y && position.y < bounds_rect.size.y);

func update_player(player_node):
	var projected_player_position = player_node.position / TILE_SIZE;
	var new_player_position = projected_player_position + player_movement_direction();
	if in_bounds_of(_world_map, new_player_position) && !is_solid_tile(_world_map, new_player_position):
		player_node.position = new_player_position * TILE_SIZE;

func _process(_delta):
	update_player($PlayerSprite);
