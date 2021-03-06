extends ColorRect

onready var health_bar = $Layout/Health;
onready var name_label = $Layout/Name;

const HEALTH_HEALTHY = Color(64/255.0, 120/255.0, 32/255.0, 255/255.0);
const HEALTH_MEDIUM = Color(204/255.0, 182/255.0, 35/255.0, 255/255.0);
const HEALTH_DANGER = Color(120/255.0, 32/255.0, 32/255.0, 255/255.0);

func update_from(entity):
	name_label.text = entity.name;
	health_bar.max_value = entity.max_health;
	health_bar.value = entity.health;

	var health_percentage = entity.health_percentage();
	var foreground_style = health_bar.get("custom_styles/fg");

	print(health_percentage);
	if health_percentage >= 0.6:
		foreground_style.bg_color = (HEALTH_HEALTHY);
	elif health_percentage < 0.6 and health_percentage > 0.3:
		foreground_style.bg_color = (HEALTH_MEDIUM);
	else:
		foreground_style.bg_color = (HEALTH_DANGER);
