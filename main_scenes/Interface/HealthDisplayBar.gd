extends ColorRect

onready var health_bar = $Layout/Health;
onready var name_label = $Layout/Layout/Name;
onready var status_effect_layout = $StatusEffectLayout;

const HEALTH_HEALTHY = Color(64/255.0, 120/255.0, 32/255.0, 255/255.0);
const HEALTH_MEDIUM = Color(204/255.0, 182/255.0, 35/255.0, 255/255.0);
const HEALTH_DANGER = Color(120/255.0, 32/255.0, 32/255.0, 255/255.0);

func _ready():
	set("custom_styles/fg", StyleBoxFlat.new());

func update_from(entity):
	name_label.text = entity.name;
	health_bar.max_value = entity.max_health;
	health_bar.value = entity.health;

	var health_percentage = entity.health_percentage();
	var foreground_style = health_bar.get("custom_styles/fg");

	for child in status_effect_layout.get_children():
		status_effect_layout.remove_child(child);

	if entity.adrenaline_active_timer > 0:
		var adrenaline_status_label = Label.new();
		adrenaline_status_label.text = "(ADR)";
		adrenaline_status_label.add_color_override("font_color", Color.yellow);
		status_effect_layout.add_child(adrenaline_status_label);

	if entity.current_medkit and entity.use_medkit_timer > 0:
		var use_medkit_label = Label.new();
		use_medkit_label.text = "(HEALING)";
		use_medkit_label.add_color_override("font_color", Color.green);
		status_effect_layout.add_child(use_medkit_label);

	if health_percentage >= 0.6:
		foreground_style.bg_color = (HEALTH_HEALTHY);
	elif health_percentage < 0.6 and health_percentage > 0.3:
		foreground_style.bg_color = (HEALTH_MEDIUM);
	else:
		foreground_style.bg_color = (HEALTH_DANGER);
