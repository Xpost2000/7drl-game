extends Node
var _entity_sprites;
var _chunk_views;


var entities = [];
class Entity:
	func _init(sprite):
		self.associated_sprite_node = sprite;

	func can_see_from(chunks, target_position):
		var direction = (target_position - self.position).normalized();
		var step = 0;

		var ray_position = self.position;
		while (ray_position.round() != target_position):
			ray_position = self.position + (direction * step);
			var rounded_position = ray_position.round();

			var current_chunk_location = chunks.calculate_chunk_position(rounded_position);
			var in_world_bounds = (current_chunk_location.x >= 0) && (current_chunk_location.y >= 0) && chunks.in_bounds(current_chunk_location);
			var current_chunk = chunks.world_chunks[current_chunk_location.y][current_chunk_location.x];

			var ray_relative_position = ray_position - (current_chunk_location * chunks.CHUNK_MAX_SIZE);
			if chunks.is_solid_tile(current_chunk, ray_relative_position) or (not in_world_bounds):
				return false;
			step += 0.5;
		return true;

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

func find_any_entity_collisions(position):
	for other_entity in entities:
		if other_entity.position.x == position.x && other_entity.position.y == position.y:
			return true;
	return false;

func try_move(entity, direction):

	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;
		var in_world_bounds = (_chunk_views.get_chunk_at(new_position) != null);

		if in_world_bounds:
			var chunk_position = _chunk_views.calculate_chunk_position(new_position);
			var in_bounds = _chunk_views.in_bounds_of(new_position, chunk_position.x, chunk_position.y);
			var hitting_wall = _chunk_views.is_solid_tile(new_position);
			var hitting_anyone = find_any_entity_collisions(new_position);

			if in_bounds && not hitting_wall && not hitting_anyone:
				return Enumerations.COLLISION_NO_COLLISION;
			else:
				if hitting_wall:
					return Enumerations.COLLISION_HIT_WALL;
				elif hitting_anyone:
					return Enumerations.COLLISION_HIT_ENTITY;
				elif not in_bounds:
					if in_world_bounds:
						return Enumerations.COLLISION_NO_COLLISION;
					else:
						return Enumerations.COLLISION_HIT_WORLD_EDGE;
		return Enumerations.COLLISION_HIT_WORLD_EDGE;


func move_entity(entity, direction):
	if direction != Vector2.ZERO:
		var new_position = entity.position + direction;
		var result = try_move(entity, direction);
		if result == Enumerations.COLLISION_NO_COLLISION:
			entity.position = new_position;
		return result;

func _ready():
	_entity_sprites = get_parent().get_node("Entities");
	_chunk_views = get_parent().get_node("ChunkViews");

# TODO allow for tweening.
func _process(delta):
	for entity in entities:
		var sprite_node = entity.associated_sprite_node;
		sprite_node.position = (entity.position+Vector2(0.5, 0.5)) * _chunk_views.TILE_SIZE;
