extends Control

var game
var identity := ""
var origin := ""
var bearer := ""
var epoch := 0
var busy := false
var known := false
var party: Dictionary = {}
var poll_left := 0.0
var members: Label
var status: Label
var invitation: LineEdit
var code: LineEdit
var create_button: Button
var accept_button: Button
var start_button: Button
var back_button: Button
var copy_button: Button
var return_button: Button
var ready_button: Button
var reset_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 600
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	add_label(box, "DUO / TEAM LOBBY", 28)
	add_label(box, "Invite a teammate. Both members must be ready to start.", 16)
	members = add_label(box, "", 20)
	invitation = LineEdit.new()
	invitation.editable = false
	invitation.placeholder_text = "Your invitation appears here"
	box.add_child(invitation)
	copy_button = add_button(box, "COPY INVITATION", func(): DisplayServer.clipboard_set(invitation.text))
	create_button = add_button(box, "CREATE TEAM", func(): request("/parties"))
	code = LineEdit.new()
	code.placeholder_text = "Paste a teammate's invitation"
	code.max_length = 64
	box.add_child(code)
	accept_button = add_button(box, "ACCEPT INVITATION", func(): accept_invitation())
	ready_button = add_button(box, "READY", func(): request("/parties/ready", {"ready": not own_ready()}))
	start_button = add_button(box, "START DUO OPERATION", func(): request("/parties/reserve", game.build_info.duplicate()))
	reset_button = add_button(box, "RESET MATCHMAKING", func():
		var body: Dictionary = game.build_info.duplicate()
		body.group_id = party.get("reservation_id", "")
		request("/parties/reset", body)
	)
	status = add_label(box, "", 16)
	status.custom_minimum_size = Vector2(550, 54)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = add_button(box, "LEAVE TEAM & RETURN", func(): request("/parties/current", {}, HTTPClient.METHOD_DELETE))
	return_button = add_button(box, "RETURN TO MENU", func():
		dismiss()
		game.ui.show_menu("Lobby closed. Any existing team remains active until left or expired.")
	)
	visibility_changed.connect(_sync_processing)
	hide()
	_sync_processing()

func _sync_processing() -> void:
	set_process(is_visible_in_tree())

func add_label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open(owner_game, uid: String) -> void:
	game = owner_game
	identity = uid
	origin = game.api_url
	bearer = game.token
	epoch += 1
	busy = false
	known = false
	party.clear()
	code.text = ""
	game.ui.menu.hide()
	show()
	status.text = "Checking your team…"
	render()
	request("/parties/current", {}, HTTPClient.METHOD_GET)

func dismiss() -> void:
	epoch += 1
	hide()
	party.clear()
	invitation.text = ""
	code.text = ""
	bearer = ""
	if game != null and not game.running:
		game.ui.menu.show()

func _process(dt: float) -> void:
	if not visible or busy:
		return
	poll_left -= dt
	if poll_left <= 0:
		request("/parties/current", {}, HTTPClient.METHOD_GET)

func accept_invitation() -> void:
	var value := code.text.strip_edges()
	if value.length() < 32:
		status.text = "Paste the complete invitation code."
		return
	request("/parties/accept", {"invitation": value})

func request(path: String, body := {}, method := HTTPClient.METHOD_POST) -> void:
	if busy or not visible:
		return
	busy = true
	render()
	var stamp := epoch
	var response: Dictionary = await game.http_call(path, body, false, method)
	if stamp != epoch:
		return
	busy = false
	poll_left = 2.0
	if game.token != bearer or game.api_url != origin or game.running:
		dismiss()
		return
	if response.code == 401:
		game.token = ""
		game.token_origin = ""
		game.ui.logout_button.disabled = true
		dismiss()
		game.ui.show_menu("Login expired. Sign in again to join a team.")
		return
	if response.code != 200:
		status.text = "Team request failed: " + game.error_message(response)
		poll_left = 5.0
		render()
		return
	if method == HTTPClient.METHOD_DELETE:
		dismiss()
		game.ui.show_menu("Team left. Pending reservations released.")
		return
	party = response.body
	known = true
	if party.has("admission"):
		var admission: Dictionary = party.admission
		var auth := bearer
		dismiss()
		game.ui.busy = true
		game.ui.connection_cancel.disabled = false
		game.connect_admission(admission, origin, auth, "duo", game.connection_attempt)
		return
	if party.is_empty():
		status.text = "Create a team or accept an invitation."
	elif party.get("status", "") == "reserved":
		status.text = "Once both members leave the operation, the leader can reset matchmaking and keep this team."
	elif party.members.size() == 1:
		status.text = "Waiting for your teammate. Invitations expire after 15 minutes."
	else:
		code.text = ""
		status.text = "Both members ready. The leader can start." if all_ready() else "Mark yourself ready when you are ready to deploy."
	render()

func own_ready() -> bool:
	for member in party.get("members", []):
		if member.uid == identity:
			return member.get("ready", false)
	return false

func all_ready() -> bool:
	var roster: Array = party.get("members", [])
	return roster.size() == 2 and roster.all(func(member): return member.get("ready", false))

func render() -> void:
	var forming: bool = party.get("status", "") == "forming"
	var has_party := not party.is_empty()
	create_button.disabled = busy or not known or has_party
	accept_button.disabled = create_button.disabled
	code.editable = not accept_button.disabled
	start_button.disabled = busy or not forming or party.get("leader", "") != identity or not all_ready()
	ready_button.visible = has_party
	ready_button.disabled = busy or not forming or party.get("members", []).size() != 2
	ready_button.text = "CANCEL READY" if own_ready() else "READY"
	back_button.disabled = busy
	return_button.disabled = busy
	create_button.visible = not has_party
	accept_button.visible = not has_party
	code.visible = not has_party
	start_button.visible = has_party
	reset_button.visible = party.get("status", "") == "reserved"
	reset_button.disabled = busy or party.get("leader", "") != identity
	back_button.visible = has_party
	invitation.text = party.get("invitation", "")
	copy_button.disabled = invitation.text.is_empty()
	invitation.visible = not invitation.text.is_empty()
	copy_button.visible = invitation.visible
	return_button.text = "RETURN / KEEP TEAM" if has_party else "RETURN TO MENU"
	members.text = "No active team" if known else "Loading…"
	if has_party:
		var names := PackedStringArray()
		for member in party.members:
			names.append(str(member.username) + (" / LEADER" if member.uid == party.leader else "") + (" / READY" if member.get("ready", false) else " / NOT READY"))
		members.text = "\n".join(names)
