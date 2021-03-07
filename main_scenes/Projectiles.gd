extends Node2D
# a copy and paste of Entities.gd

var projectiles = [];

class Projectile:
	var damage: int;
	var position: Vector2;
	var direction: Vector2;
	var dead: bool;
	var owner: Object;
	func tick(game_state):
		pass;
class PipebombProjectile extends Projectile:
	const EntityBrain = preload("res://main_scenes/EntityBrain.gd");
	class EntityPipebombBrain  extends EntityBrain:
		var timer: int;
		func _init():
			self.timer = 4;
		func get_turn_action(entity_self, game_state):
			if self.timer <= 0:
				entity_self.health = -999;
				game_state.add_explosion(entity_self.position, 4, 90, Enumerations.EXPLOSION_TYPE_NORMAL);
				print("explode");
			else:
				self.timer -= 1;
				AudioGlobal.play_sound("resources/snds/pipebomb/beep.wav");
			return EntityBrain.WaitTurnAction.new();

	var lifetime: int;
	func _init(position, direction):
		self.position = position;
		self.direction = direction;
		self.lifetime = 8;
		self.dead = false;
	func tick(game_state):
		var old_position = self.position;
		if self.lifetime < 0:
			self.dead = true;
		else:
			self.position += self.direction;
			self.lifetime -= 1;

			if game_state._world.is_solid_tile(self.position.round()):
				self.dead = true;
			for entity in game_state._entities.entities:
				if entity.position == self.position.round():
					entity.health -= 10;
					self.dead = true;
					entity.on_hit(game_state, self.owner);
					break;
		if self.dead:
			var bomb = game_state._entities.add_entity("Pipebomb", old_position.round(), EntityPipebombBrain.new());
			bomb.visual_info.symbol = "P";
			bomb.visual_info.foreground = Color(1, 1, 1, 1);
			
class MolotovProjectile extends Projectile:
	func _init(position, direction):
		self.position = position;
		self.direction = direction;
		self.dead = false;
	func tick(game_state):
		var old_position = self.position;
		self.position += self.direction;

		if game_state._world.is_solid_tile(self.position.round()):
			self.dead = true;
		for entity in game_state._entities.entities:
			if entity.position == self.position.round():
				entity.health -= 10;
				self.dead = true;
				entity.on_hit(game_state, self.owner);
				break;
		if self.dead:
			self.position = self.position.round();
			game_state.add_explosion(self.position, 2, 15, Enumerations.EXPLOSION_TYPE_FIRE);
class BoomerBileProjectile extends Projectile:
	func _init(position, direction):
		self.position = position;
		self.direction = direction;
		self.dead = false;
	func tick(game_state):
		var old_position = self.position;
		self.position += self.direction;

		if game_state._world.is_solid_tile(self.position.round()):
			self.dead = true;
		for entity in game_state._entities.entities:
			if entity.position == self.position.round():
				entity.health -= 10;
				self.dead = true;
				entity.on_hit(game_state, self.owner);
				break;
		if self.dead:
			self.position = self.position.round();
			game_state.add_explosion(self.position, 2, 0, Enumerations.EXPLOSION_TYPE_BOOMERBILE);
class BulletProjectile extends Projectile:
	var lifetime: int;
	var penetration_health: int;
	func _init(position, direction):
		self.position = position;
		self.direction = direction;
		self.lifetime = 10;
		self.penetration_health = 0;
		self.dead = false;
	func tick(game_state):
		if self.lifetime < 0:
			self.dead = true;
		else:
			self.position += self.direction;
			self.lifetime -= 1;

			if game_state._world.is_solid_tile(self.position):
				self.dead = true;
			for entity in game_state._entities.entities:
				if entity.position == self.position.round():
					entity.health -= 40;
					self.penetration_health -= 1;
					entity.on_hit(game_state, self.owner);
					if self.penetration_health < 0:
						self.dead = true;
						break;

func remove_projectile_at_index(index):
	projectiles.remove(index);

func remove_projectile(projectile):
	remove_projectile_at_index(projectiles.find(projectile));

func add_projectile(projectile):
	projectiles.push_back(projectile);

func _process(_delta):
	var deletion_list = [];
	for projectile in projectiles:
		# var sprite_node = entity.associated_sprite_node;
		# sprite_node.position = (entity.position+Vector2(0.5, 0.5)) * _chunk_views.TILE_SIZE;
		if projectile.dead:
			deletion_list.push_back(projectile);

	for projectile in deletion_list:
		remove_projectile(projectile);
