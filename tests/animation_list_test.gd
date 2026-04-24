extends Node

func test_animation_list() -> void:
	var scene = load("res://scenes/Warrior.tscn").instantiate()
	var anim_player = scene.get_node_or_null("AnimationPlayer")
	assert(anim_player, "AnimationPlayer not found in Warrior scene")
	var animations: Array = anim_player.get_animation_list()
	var file = FileAccess.open("res://animation_list.txt", FileAccess.WRITE)
	file.store_string("AnimationPlayer animations:\n")
	for name in animations:
		file.store_line(name)
	file.close()
	assert(animations.size() > 0)
