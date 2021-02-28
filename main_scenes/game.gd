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
	var first = create_tween(node, "position", start, start + direction * ($ChunkViews.TILE_SIZE/2), Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);
	first.start();
	var second = create_tween(node, "position", start + direction * ($ChunkViews.TILE_SIZE/2), start, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.25);

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

const HIT_WALL = 0;
const HIT_WORLD_EDGE = 1;
const NO_COLLISION = 2;

func update_player(player_entity):
	var move_result = $Entities.move_entity(player_entity, player_movement_direction());
	match move_result:
		HIT_WALL: _message_log.push_message("You bumped into a wall.");
		HIT_WORLD_EDGE: _message_log.push_message("You hit the edge of the world.");

var _last_known_current_chunk_position;
func _ready():
	$Entities.add_entity("Sean", Vector2.ZERO);
	_last_known_current_chunk_position = $ChunkViews.calculate_chunk_position($Entities.entities[0].position);

func _process(_delta):
	var current_chunk_position = $ChunkViews.calculate_chunk_position($Entities.entities[0].position);
	if _last_known_current_chunk_position != current_chunk_position:
		for chunk_row in $ChunkViews.world_chunks:
			for chunk in chunk_row:
				chunk.mark_all_dirty();
		for chunk_view in $ChunkViews.get_children():
			chunk_view.clear();
		$ChunkViews.inclusively_redraw_chunks_around(current_chunk_position);
		$ChunkViews.repaint_animated_tiles(current_chunk_position);

	$ChunkViews.inclusively_redraw_chunks_around(current_chunk_position);

	$CameraTracer.position = $Entities.entities[0].associated_sprite_node.global_position;
	update_player($Entities.entities[0]);
	_last_known_current_chunk_position = current_chunk_position;

func _physics_process(_delta):
	pass;
