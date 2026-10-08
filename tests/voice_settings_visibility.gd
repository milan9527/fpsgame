extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	var setup = load("res://scripts/voice_settings.gd").new()
	host.add_child(setup)
	await process_frame
	assert(not setup.is_processing_input(), "Closed setup must not receive gameplay input")
	setup.open()
	assert(setup.is_processing_input(), "Opening must restore input handling")
	setup.update_level(0.75, true, true, 0)
	assert(setup.meter.value == 75)
	assert("clipping" in setup.status.text)
	setup.testing = true
	setup.close()
	assert(not setup.testing)
	assert(not setup.is_processing_input())
	setup.open()
	assert(setup.meter.value == 0, "Reopening must clear the old test meter")
	assert(setup.status.text == "Hold below to check input. No audio is sent.")
	host.hide()
	assert(not setup.is_processing_input(), "Hidden ancestor must suspend input too")
	host.show()
	assert(setup.is_processing_input())
	host.queue_free()
	await process_frame
	print("VOICE_SETTINGS_VISIBILITY_PASS")
	quit()
