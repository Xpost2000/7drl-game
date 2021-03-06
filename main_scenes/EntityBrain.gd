# Rely on type dispatch for things.
# Technically since it's dynamically typed there's no reason to do extends.
# I just want to semantically define it though.
# This is where you define all actions as well I guess.
class TurnAction:
	func do_action(game_state, target):
		pass;
class WaitTurnAction:
	func do_action(game_state, target):
		pass;
class MoveTurnAction extends TurnAction:
	func _init(direction):
		self.direction = direction;
	func do_action(game_state, target):
		game_state._entities.move_entity(target, self.direction);
	var direction: Vector2;

class UseItemAction:
	var item_picked: Object;
	func _init(item):
		self.item_picked = item;

	func do_action(game_state, target):
		item_picked.on_use(game_state, target);

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
			user.currently_equipped_weapon.on_fire(game_state, user, (target_location - user.position).normalized());
class AttackTurnAction extends TurnAction:
	# Game specific.
	pass

func get_turn_action(entity_self, game_state):
	return WaitTurnAction.new();
