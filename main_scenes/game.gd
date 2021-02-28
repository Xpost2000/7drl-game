extends Node2D

# Just quickly seeing what would get me a decent organization structure.
# Doing a roguelike might require me to do a lot of perversion of the idiomatic godot way
# in which case I'm just writing a python roguelike engine and using godot as my driver/client...
# Which works I guess?

# It gets stuff done really fast even though it ain't maintainable. If godot supported less node based modules
# it'd be way easier to do things...

# Particularly the turnbased part. As to avoid giving myself a headache I can just
# register the turns centrally here...
# If it were real time, I'd do the nodes...

onready var _world_map = $ChunkViews/Current;
onready var _message_log = $InterfaceLayer/Interface/Messages;
onready var _entity_sprites = $EntitySprites;

const TILE_SIZE = 32;

func create_tween(node_to_tween, property, start, end, tween_fn, tween_ease, time=1.0, delay=0.0):
	var new_tween = Tween.new();
	new_tween.interpolate_property(node_to_tween, property, start, end, time, tween_fn, tween_ease, delay)
	new_tween.connect("tween_all_completed", self, "remove_child", [new_tween]);
	new_tween.connect("tween_all_completed", new_tween, "queue_free");
	add_child(new_tween);
	return new_tween;

func movement_tween(node, start, end):
	create_tween(node, "position", start, end, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25).start();

func bump_tween(node, start, direction):
	var first = create_tween(node, "position", start, start + direction * (TILE_SIZE/2), Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);
	first.start();
	var second = create_tween(node, "position", start + direction * (TILE_SIZE/2), start, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);

	first.connect("tween_all_completed", second, "start");

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

# for now keep this in sync with tileset...
var _solid_cells_list = [8, 9];
func is_solid_tile(world_map, position) -> bool:
	# this shouldn't happen, however it is cause the tiles are relative to the chunk position.
	if $ChunkViews.in_bounds_of(position, 0, 0):
		var cell_at_position = world_map.get_cell(position.x, position.y);
		for cell in _solid_cells_list:
			if cell == cell_at_position:
				return true;
	return false;

# might be uber class?
# everything will probably only have one turn, to be safe?
# TODO support multi turn entities
func calculate_chunk_position(absolute_position):
	return Vector2(int(absolute_position.x / $ChunkViews.CHUNK_MAX_SIZE), int(absolute_position.y / $ChunkViews.CHUNK_MAX_SIZE));
class Entity:
	func _init(sprite):
		self.associated_sprite_node = sprite;

	var name: String;
	var health: int;
	var position: Vector2;
	var associated_sprite_node: Sprite;
var entities = [];
func remove_entity_at_index(index):
	var sprite = entities[index].associated_sprite_node;
	entities.remove(index);
	_entity_sprites.remove_child(sprite);
	sprite.queue_free();

func add_entity(name, position):
	var sprite = Sprite.new();

	var atlas_texture = AtlasTexture.new();
	atlas_texture.atlas = load("res://resources/ProjectUtumno_full.png");
	atlas_texture.region = Rect2(450, 1890, 30, 30);

	sprite.texture = atlas_texture;
	_entity_sprites.add_child(sprite);

	var new_entity = Entity.new(sprite);
	new_entity.name = name;
	new_entity.position = position;

	entities.push_back(new_entity);
	return new_entity;

const HIT_WALL = 0;
const HIT_WORLD_EDGE = 1;
const NO_COLLISION = 2;

func try_move(entity, direction):
	var chunk_position = calculate_chunk_position(entity.position);
	var current_chunk = $ChunkViews.world_chunks[chunk_position.y][chunk_position.x];

	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;

		var in_world_bounds = (new_position.x >= 0) && (new_position.y >= 0) && $ChunkViews.in_bounds(calculate_chunk_position(new_position));
		var in_bounds = $ChunkViews.in_bounds_of(new_position, chunk_position.x, chunk_position.y);
		var hitting_wall = is_solid_tile(current_chunk, new_position - Vector2(chunk_position.x * $ChunkViews.CHUNK_MAX_SIZE, chunk_position.y * $ChunkViews.CHUNK_MAX_SIZE));
		if in_bounds && not hitting_wall:
			return NO_COLLISION;
		else:
			if hitting_wall:
				return HIT_WALL;
			elif not in_bounds:
				if in_world_bounds:
					return NO_COLLISION;
				else:
					return HIT_WORLD_EDGE;


func move_entity(entity, direction):
	var sprite_node = entity.associated_sprite_node;
	sprite_node.position = (entity.position+Vector2(0.5, 0.5)) * TILE_SIZE;

	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;
		var result = try_move(entity, direction);
		if result == NO_COLLISION:
			entity.position = new_position;
		return result;

func update_player(player_entity):
	var move_result = move_entity(player_entity, player_movement_direction());
	match move_result:
		HIT_WALL: _message_log.push_message("You bumped into a wall.");
		HIT_WORLD_EDGE: _message_log.push_message("You hit the edge of the world.");

var _last_known_current_chunk_position;
func _ready():
	add_entity("Sean", Vector2.ZERO);
	_last_known_current_chunk_position = calculate_chunk_position(entities[0].position);

func _process(_delta):
	var current_chunk_position = calculate_chunk_position(entities[0].position);
	if _last_known_current_chunk_position != current_chunk_position:
		for chunk_row in $ChunkViews.world_chunks:
			for chunk in chunk_row:
				chunk.mark_all_dirty();
		for chunk_view in $ChunkViews.get_children():
			chunk_view.clear();
		$ChunkViews.inclusively_redraw_chunks_around(current_chunk_position);
		$ChunkViews.repaint_animated_tiles(current_chunk_position);

	$ChunkViews.inclusively_redraw_chunks_around(current_chunk_position);

	$CameraTracer.position = entities[0].associated_sprite_node.global_position;
	update_player(entities[0]);
	_last_known_current_chunk_position = current_chunk_position;

func _physics_process(_delta):
	pass;
