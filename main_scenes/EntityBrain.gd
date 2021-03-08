# Rely on type dispatch for things.
# Technically since it's dynamically typed there's no reason to do extends.
# I just want to semantically define it though.
# This is where you define all actions as well I guess.
class TurnAction:
	func do_action(game_state, target):
		pass;
class WaitTurnAction extends TurnAction:
	func do_action(game_state, target):
		pass;
class MoveTurnAction extends TurnAction:
	func _init(direction):
		self.direction = direction;
	func do_action(game_state, target):
		game_state._entities.move_entity(target, self.direction);
	var direction: Vector2;
class PickupItemTurnAction extends TurnAction:
	var item: Object;
	func _init(item):
		self.item = item;
	func do_action(game_state, target):
		if self.item:
			target.add_item(self.item.item);
			game_state._entities.remove_item_pickup(self.item);
class UseItemAction extends TurnAction:
	var item_picked: Object;
	func _init(item):
		self.item_picked = item;

	func do_action(game_state, target):
		item_picked.on_use(game_state, target);
class ShoveTurnAction extends TurnAction:
	var direction: Vector2;
	func _init(direction):
		self.direction = direction;
	func do_action(game_state, target):
		var who = game_state._entities.get_entity_at_position(target.position + self.direction);
		who.on_hit(game_state, target);
		if who:
			var move_result_first = game_state._entities.try_move(who, self.direction);
			if move_result_first == Enumerations.COLLISION_NO_COLLISION:
				who.position += self.direction;
				var move_result_second = game_state._entities.try_move(who, self.direction);
				if move_result_second:
					who.position += self.direction;
				else:
					who.health *= 0.9;
					who.health -= 5;
			else:
				who.health *= 0.8;
				who.health -= 5;
			AudioGlobal.play_sound("resources/snds/rifle_swing_hit_infected12.wav");
class TankPunchTurnAction extends TurnAction:
	var direction: Vector2;
	var target: Object;
	func _init(direction, target):
		self.direction = direction;
		self.target = target;
	func do_action(game_state, target):
		var who = self.target;
		who.on_hit(game_state, target);
		if who:
			var move_result_first = game_state._entities.try_move(who, self.direction);
			if move_result_first == Enumerations.COLLISION_NO_COLLISION:
				who.position += self.direction;
				var move_result_second = game_state._entities.try_move(who, self.direction);
				if move_result_second:
					who.position += self.direction;
				else:
					who.health -= 25;
			else:
				who.health -= 35;
			who.health -= 25;
			AudioGlobal.play_sound("resources/snds/tank/tank_attack_04.wav");
			AudioGlobal.play_sound("resources/snds/tank/hulk_punch_1.wav");
			AudioGlobal.play_sound("resources/snds/rifle_swing_hit_infected12.wav");
class HealingAction extends TurnAction:
	func do_action(game_state, target):
		target.current_medkit.uses_left -= 1;
		target.use_medkit_timer -= 1;
		var damaged_amount = target.max_health - target.health;
		if target.current_medkit.uses_left <= 0:
			target.remove_item(target.current_medkit);
			target.current_medkit = null;
			target.use_medkit_timer = 0;
		else:
			target.health += (damaged_amount * 0.9235/Globals.HEALING_MEDKIT_TURNS); 
class FireWeaponTurnAction extends TurnAction:
	var target_location;
	func _init(target_where):
		target_location = target_where;
	func do_action(game_state, user):
		if user.currently_equipped_weapon:
#			if user.currently_equipped_weapon.rounds_per_shot > 1:
#				user.rounds_left_in_burst = user.currently_equipped_weapon.rounds_per_shot;
			user.currently_equipped_weapon.on_fire(game_state, user, (target_location - user.position).normalized());
class ReloadWeaponTurnAction extends TurnAction:
	func _init():
		pass;
	func do_action(game_state, user):
		if user.currently_equipped_weapon:
			user.currently_equipped_weapon.reload();
class AttackTurnAction extends TurnAction:
	var target: Object;
	var damage: int;
	func _init(target, damage):
		self.target = target;
		self.damage = damage;
	func do_action(game_state, user):
		if self.target:
			self.target.health -= self.damage;
			self.target.on_hit(game_state, user);
class SmokerTongueSuckTurnAction extends TurnAction:
	var target: Object;
	var damage: int;
	func _init(target):
		self.target = target;
		self.damage = damage;
	func do_action(game_state, user):
		if self.target and self.target.smoker_link == null:
			self.target.smoker_link = user;
func on_hit(game_state, self_entity, from):
	pass;
func get_turn_action(entity_self, game_state):
	return WaitTurnAction.new();
