extends Control

signal close_requested
signal pickup_requested(id: int)
signal equipment_requested(action: String, index: int)
signal drop_requested(kind: int, count: int)
const Bindings = preload("res://scripts/control_bindings.gd")
var title: Label
const SupplyRules = preload("res://scripts/supply_rules.gd")
var stock: Label
var empty: Label
var nearby: VBoxContainer
var rows := {}
var weapons: Array[Button] = []
var reload_button: Button
var heal_button: Button
var grip_button: Button
var drop_kind: OptionButton
var drop_count: SpinBox
var drop_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.078, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(220, 105)
	panel.size = Vector2(1000, 660)
	panel.add_theme_constant_override("separation", 18)
	add_child(panel)
	title = Label.new()
	title.text = "FIELD INVENTORY    /    B OR ESC TO CLOSE"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	var warning := Label.new()
	warning.text = "The operation continues while browsing. Find cover before opening."
	panel.add_child(warning)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	panel.add_child(columns)
	var equipment := VBoxContainer.new()
	equipment.custom_minimum_size.x = 410
	equipment.add_theme_constant_override("separation", 12)
	columns.add_child(equipment)
	stock = Label.new()
	equipment.add_child(stock)
	for index in range(3):
		var b := Button.new()
		b.pressed.connect(func(): equipment_requested.emit("weapon", index))
		equipment.add_child(b)
		weapons.append(b)
	reload_button = Button.new()
	reload_button.text = "RELOAD EQUIPPED WEAPON"
	reload_button.pressed.connect(func(): equipment_requested.emit("reload", -1))
	equipment.add_child(reload_button)
	heal_button = Button.new()
	heal_button.text = "USE MEDKIT"
	heal_button.pressed.connect(func(): equipment_requested.emit("heal", -1))
	equipment.add_child(heal_button)
	grip_button = Button.new()
	grip_button.pressed.connect(func(): equipment_requested.emit("grip", -1))
	equipment.add_child(grip_button)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 550
	columns.add_child(right)
	var heading := Label.new()
	heading.text = "NEARBY SUPPLIES    /    CLICK TO TAKE"
	right.add_child(heading)
	empty = Label.new()
	empty.text = "No reachable supplies within 2.8 m."
	right.add_child(empty)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(550, 240)
	right.add_child(scroll)
	nearby = VBoxContainer.new()
	nearby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(nearby)
	var drop_title := Label.new()
	drop_title.text = "DROP CARRIED SUPPLIES AT YOUR FEET"
	right.add_child(drop_title)
	var drop_row := HBoxContainer.new()
	right.add_child(drop_row)
	drop_kind = OptionButton.new()
	for kind in [0, 1, 3, 4, 5]:
		drop_kind.add_item(SupplyRules.NAMES[kind], kind)
	drop_row.add_child(drop_kind)
	drop_count = SpinBox.new()
	drop_count.min_value = 1
	drop_count.max_value = 300
	drop_count.step = 1
	drop_count.value = 1
	drop_count.custom_minimum_size.x = 110
	drop_row.add_child(drop_count)
	drop_button = Button.new()
	drop_button.text = "DROP"
	drop_button.pressed.connect(func(): drop_requested.emit(drop_kind.get_selected_id(), int(drop_count.value)))
	drop_row.add_child(drop_button)
	var close := Button.new()
	close.text = "RETURN TO OPERATION"
	close.pressed.connect(func(): close_requested.emit())
	panel.add_child(close)
	hide()

func refresh(actor, supplies: Array) -> void:
	title.text = "FIELD INVENTORY    /    %s OR ESC TO CLOSE" % Bindings.key_label("inventory")
	stock.text = "CARRIED SUPPLIES\n\nAMMUNITION  %d / 300\nMEDKITS  %d / 5     FRAGS  %d / 4\nSMOKE  %d / 3     ARMOR  %d / 100\n\nWEAPONS / LOADED MAGAZINES" % [actor.reserve, actor.medkits, actor.grenades, actor.smokes, actor.armor]
	for index in range(3):
		weapons[index].text = "%s  %s   %d / %d" % ["EQUIPPED" if index == actor.weapon else "EQUIP", ["AR-30", "SG-8", "SR-5"][index], actor.magazines[index], actor.CAPACITY[index]]
		if actor.grip_slots[index] == 1:
			weapons[index].text += "  + GRIP"
		weapons[index].disabled = index == actor.weapon or actor.reload_left > 0 or actor.throw_left > 0
	reload_button.disabled = actor.reserve <= 0 or actor.ammo >= actor.CAPACITY[actor.weapon] or actor.heal_left > 0 or actor.reload_left > 0 or actor.throw_left > 0
	heal_button.text = "CANCEL MEDKIT" if actor.heal_left > 0 else "USE MEDKIT"
	heal_button.disabled = not actor.alive or (actor.heal_left <= 0 and (actor.medkits <= 0 or actor.health >= 100 or actor.reload_left > 0 or actor.throw_left > 0))
	grip_button.text = ("REMOVE FOREGRIP" if actor.grip_slots[actor.weapon] == 1 else "INSTALL FOREGRIP / 20% LESS KICK") + "  /  %d SPARE" % actor.grips
	grip_button.disabled = actor.reload_left > 0 or actor.heal_left > 0 or actor.throw_left > 0 or (actor.grips >= 3 if actor.grip_slots[actor.weapon] == 1 else actor.grips <= 0)
	var kind := drop_kind.get_selected_id()
	var available := int(actor.get(SupplyRules.FIELDS[kind]))
	drop_count.max_value = maxi(1, available)
	drop_button.disabled = available <= 0 or (kind == 1 and actor.heal_left > 0)
	var present := {}
	for item in supplies:
		var id: int = item.id
		present[id] = true
		if not rows.has(id):
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func(): pickup_requested.emit(id))
			nearby.add_child(b)
			rows[id] = b
		var quantity := String.num(item.amount, 1) if not is_equal_approx(item.amount, roundf(item.amount)) else str(int(item.amount))
		rows[id].text = "%s ×%s   /   %.1f m%s" % [SupplyRules.NAMES[item.kind], quantity, item.distance, "   FULL" if not item.usable else ""]
		rows[id].disabled = not item.usable
	for id in rows.keys():
		if not present.has(id):
			nearby.remove_child(rows[id])
			rows[id].queue_free()
			rows.erase(id)
	empty.visible = supplies.is_empty()
