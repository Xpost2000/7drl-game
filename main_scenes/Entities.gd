extends Node
var _entity_sprites;
var _chunk_views;

const HIT_WALL = 0;
const HIT_WORLD_EDGE = 1;
const NO_COLLISION = 2;

var entities = [];
class Entity:
	func _init(sprite):
		self.associated_sprite_node = sprite;

	var name: String;
	var health: int;
	var position: Vector2;
	var associated_sprite_node: Sprite;

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

func try_move(entity, direction):
	var chunk_position = _chunk_views.calculate_chunk_position(entity.position);
	var current_chunk = _chunk_views.world_chunks[chunk_position.y][chunk_position.x];

	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;

		var in_world_bounds = (new_position.x >= 0) && (new_position.y >= 0) && _chunk_views.in_bounds(_chunk_views.calculate_chunk_position(new_position));
		var in_bounds = _chunk_views.in_bounds_of(new_position, chunk_position.x, chunk_position.y);
		var hitting_wall = _chunk_views.is_solid_tile(current_chunk, new_position - Vector2(chunk_position.x * _chunk_views.CHUNK_MAX_SIZE, chunk_position.y * _chunk_views.CHUNK_MAX_SIZE));
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
	sprite_node.position = (entity.position+Vector2(0.5, 0.5)) * _chunk_views.TILE_SIZE;

	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;
		var result = try_move(entity, direction);
		if result == NO_COLLISION:
			entity.position = new_position;
		return result;

func _ready():
	_entity_sprites = get_parent().get_node("Entities");
	_chunk_views = get_parent().get_node("ChunkViews");
	pass

func _process(delta):
	pass
