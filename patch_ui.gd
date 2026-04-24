@tool
extends EditorScript

func _run():
	var warrior_scene = load("res://scenes/Warrior.tscn")
	var warrior = warrior_scene.instantiate()
	var ui_node = warrior.get_node("UI")
	
	var archer_scene = load("res://scenes/Archer.tscn")
	var archer = archer_scene.instantiate()
	
	# Remove old UI if exists
	if archer.has_node("UI"):
		var old = archer.get_node("UI")
		archer.remove_child(old)
		old.queue_free()
		
	var new_ui = ui_node.duplicate()
	archer.add_child(new_ui)
	new_ui.owner = archer
	
	for child in new_ui.find_children("*", "", true, false):
		child.owner = archer
	
	var packed = PackedScene.new()
	packed.pack(archer)
	ResourceSaver.save(packed, "res://scenes/Archer.tscn")
	print("Archer UI successfully replaced!")
