extends Node2D
# a copy and paste of Entities.gd

var projectiles = [];

class Projectile:
	var damage: int;
	var position: Vector2;
	var direction: Vector2;
	var dead: bool;
	func tick(game_state):
		pass;
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
