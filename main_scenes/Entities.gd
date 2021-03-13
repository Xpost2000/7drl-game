extends Node2D
signal _on_entity_do_action(entity, action);

var _entity_sprites;
var _chunk_views;

var entities = [];
const FLAG_DO_NOT_REMOVE_ON_DEATH = 1;

class ItemPickup:
	class VisualInfo:
		func _init(symbol='?', foreground=Color.lightskyblue, background=Color.gold):
			self.symbol = symbol;
			self.foreground = foreground;
			self.background = background;
		var symbol: String;
		var foreground: Color;
		var background: Color;
	var visual_info: VisualInfo;
	var position: Vector2;
	var item: Object;
	func _init(item):
		self.position = Vector2.ZERO;
		self.visual_info = VisualInfo.new();
		self.item = item;

var item_pickups = []; # I will probably move this later
const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
# scary god class.
class Entity:
	class VisualInfo:
		func _init(symbol='@', foreground=Color.red, background=Color.black):
			self.symbol = symbol;
			self.foreground = foreground;
			self.background = background;
		var symbol: String;
		var foreground: Color;
		var background: Color;

	const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
	var visual_info: VisualInfo;
	func _init(sprite, brain=EntityBrain.new()):
		self.associated_sprite_node = sprite;
		self.visual_info = VisualInfo.new();
		self.max_health = 100;
		self.health = self.max_health;
		self.wait_time = 0;
		self.wait_time_between_turns = 0;
		self.turn_speed = 1;
		self.brain = brain;
		self.inventory = [];
		self.adrenaline_active_timer = 0;

	func find_best_gun_item():
		var best_item = null;
		for item in self.inventory:
			if item is Globals.Gun:
				if not best_item or best_item.tier < item.tier:
					if item.capacity > 0:
						best_item = item;
		return best_item;

	func find_medkit():
		for item in self.inventory:
			if item is Globals.Medkit:
				return item;
		return null;

	func resupply_weapons():
		for item in self.inventory:
			if item is Globals.Gun:
				item.current_capacity = item.current_capacity_limit;
				item.capacity = item.max_capacity;

	func find_closest_entity(game_state, account_for_visibility_map=false):
		var closest_entity = null;
		var closest_distance = INF;
		for entity in game_state._entities.entities:
			if entity != self and game_state._world.is_cell_visible(entity.position) and (self.can_see_from(game_state._world, entity.position) or (not account_for_visibility_map)):
				var distance = self.position.distance_to(entity.position);
				if distance < closest_distance:
					closest_distance = distance;
					closest_entity = entity;
		return closest_entity;
	# not_zombies.. REALLY? Man that's seriously fucked.
	func find_closest_zombie_entity(game_state, not_zombies, account_for_visibility_map=false):
		var closest_entity = null;
		var closest_distance = INF;
		for entity in game_state._entities.entities:
			if entity != self and (not not_zombies.has(entity)) and game_state._world.is_cell_visible(entity.position) and (self.can_see_from(game_state._world, entity.position) or (not account_for_visibility_map)):
				var distance = self.position.distance_to(entity.position);
				if distance < closest_distance:
					closest_distance = distance;
					closest_entity = entity;
		return closest_entity;

	func health_percentage():
		return float(self.health) / float(self.max_health);
	# do not duplicate items like guns.
	# that's a todo
	func add_item(item):
		self.inventory.append(item);
	func remove_item(item):
		self.inventory.erase(item);

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

	func get_turn_speed():
		if self.adrenaline_active_timer > 0:
			return self.turn_speed * 2;
		else:
			return self.turn_speed;

	func get_turn_action(game_state):
		if self.brain:
			return self.brain.get_turn_action(self, game_state);
		return null;

	func is_dead():
		return (health <= 0);
	
	func bleed(game_state, direction):
		var base_angle = direction.angle();
		for degree_spread in range(0, 45, 15):
			var angle_rad = (degree_spread + (base_angle * 180.0/PI) + 35) * PI/180;
			var new_direction = Vector2(cos(angle_rad), sin(angle_rad));
			for distance in (randi()%3+2):
				game_state._world.set_cell_gore((self.position+new_direction*distance).round(), true);
			
	func on_hit(game_state, from):
		self.brain.on_hit(game_state, self, from);

	var name: String;
	var turn_speed: int;
	var wait_time: int;
	var inventory: Array;

	var wait_time_between_turns: int;

	var max_health: int;
	var health: int;
	var adrenaline_active_timer: int;

	var position: Vector2;
	var associated_sprite_node: Sprite;
	var flags: int;
	var brain: EntityBrain;

	# specific state. Honestly even not in a jam I'm not quite sure
	# how to best handle entity-entity interactions that are stateful
	# like this... I need to make more things...
	var smoker_link: Object;

	# item related state cause this is faster to do
	var current_medkit: Object;
	var use_medkit_timer: int;
	var rounds_left_in_burst: int;
	var currently_equipped_weapon: Object;

func remove_entity_at_index(index):
	var sprite = entities[index].associated_sprite_node;
	entities.remove(index);
	_entity_sprites.remove_child(sprite);
	sprite.queue_free();
func remove_item_pickup_at_index(index):
	item_pickups.remove(index);

func remove_entity(entity):
	remove_entity_at_index(entities.find(entity));
func remove_item_pickup(item_pickup):
	remove_item_pickup_at_index(item_pickups.find(item_pickup));

func add_item_pickup(position, item):
	var new_pickup = ItemPickup.new(item);
	new_pickup.position = position;
	item_pickups.push_back(new_pickup);
	return new_pickup;

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

func get_entity_at_position(position):
	for other_entity in entities:
		if other_entity.position.x == position.x && other_entity.position.y == position.y:
			return other_entity;
	return null;

func get_item_pickup_at_position(position):
	for item_pickup in item_pickups:
		if item_pickup.position.x == position.x && item_pickup.position.y == position.y:
			return item_pickup;
	return null;

func find_any_entity_collisions(position):
	return get_entity_at_position(position) != null;

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

func do_action(game_state, entity_target, turn_action):
	# only allow healing for passive actions like wait turn
	# basically it's a state.
	if entity_target.smoker_link:
		var direction_to_smoker = entity_target.smoker_link.position - entity_target.position;
		if direction_to_smoker.x > 0:
			direction_to_smoker.x = 1;
		elif direction_to_smoker.x < 0:
			direction_to_smoker.x = -1;
		
		if direction_to_smoker.y > 0:
			direction_to_smoker.y = 1;
		elif direction_to_smoker.y < 0:
			direction_to_smoker.y = -1;
		
		var travel_to = EntityBrain.MoveTurnAction.new(direction_to_smoker);
		if game_state._entities.try_move(entity_target, direction_to_smoker) != Enumerations.COLLISION_NO_COLLISION:
			entity_target.health -= 3;
		else:
			travel_to.do_action(game_state, entity_target);

	if turn_action is EntityBrain.WaitTurnAction and entity_target.current_medkit and entity_target.use_medkit_timer >= 0:
		var healing_action = EntityBrain.HealingAction.new();
		emit_signal("_on_entity_do_action", entity_target, healing_action);
		healing_action.do_action(game_state, entity_target);
		# if game_state._player == entity_target:
		#	AudioGlobal.play_sound("resources/snds/bandaging_1.wav");

	if turn_action:
		emit_signal("_on_entity_do_action", entity_target, turn_action);
		if not (entity_target.smoker_link and turn_action is EntityBrain.MoveTurnAction):
			turn_action.do_action(game_state, entity_target);
		if not (turn_action is EntityBrain.WaitTurnAction):
			entity_target.current_medkit = null;

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
		if entity.is_dead():
			entity.smoker_link = null;

	for entity in deletion_list:
		remove_entity(entity);
