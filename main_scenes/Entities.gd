extends Node2D
signal _on_entity_do_action(entity, action);

var _entity_sprites;
var _chunk_views;

var entities = [];
const FLAG_DO_NOT_REMOVE_ON_DEATH = 1;

const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
class Entity:
	const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
	func _init(sprite, brain=EntityBrain.new()):
		self.associated_sprite_node = sprite;
		self.health = 20;
		self.wait_time = 0;
		self.turn_speed = 1;
		self.brain = brain;

	func can_see_from(chunks, target_position):
		var direction = (target_position - self.position).normalized();
		var step = 0;
		var ray_position = self.position;

		var last_ray_position = ray_position;
		while (ray_position.round() != target_position):
			ray_position = self.position + (direction * step);
			if chunks.is_solid_tile(last_ray_position):
				return false;
			last_ray_position = ray_position;
			step += 0.5;
		return true;

	func get_turn_action(game_state):
		if self.brain:
			return self.brain.get_turn_action(self, game_state);
		return null;

	func is_dead():
		return (health <= 0);

	var name: String;
	var turn_speed: int;
	var wait_time: int;

	var health: int;
	var position: Vector2;
	var associated_sprite_node: Sprite;
	var flags: int;
	var brain: EntityBrain;

func remove_entity_at_index(index):
	var sprite = entities[index].associated_sprite_node;
	entities.remove(index);
	_entity_sprites.remove_child(sprite);
	sprite.queue_free();

func remove_entity(entity):
	remove_entity_at_index(entities.find(entity));

func add_entity(name, position, brain=EntityBrain.new()):
	var sprite = Sprite.new();

	var atlas_texture = AtlasTexture.new();
	atlas_texture.atlas = load("res://resources/ProjectUtumno_full.png");
	atlas_texture.region = Rect2(450, 1890, 30, 30);

	sprite.texture = atlas_texture;
	_entity_sprites.add_child(sprite);

	var new_entity = Entity.new(sprite, brain);
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
	return Enumerations.NO_MOVE;

func do_action(entity_target, turn_action):
	if turn_action:
		emit_signal("_on_entity_do_action", entity_target, turn_action);
		turn_action.do_action(self, entity_target);

func _ready():
	_entity_sprites = get_parent().get_node("Entities");
	_chunk_views = get_parent().get_node("ChunkViews");

# TODO allow for tweening.
func _process(delta):
	var deletion_list = [];
	for entity in entities:
		var sprite_node = entity.associated_sprite_node;
		sprite_node.position = (entity.position+Vector2(0.5, 0.5)) * _chunk_views.TILE_SIZE;
		if entity.is_dead() and not (entity.flags & FLAG_DO_NOT_REMOVE_ON_DEATH):
			deletion_list.push_back(entity);

	for entity in deletion_list:
		remove_entity(entity);
