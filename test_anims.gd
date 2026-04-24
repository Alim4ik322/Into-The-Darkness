extends Node

func test_anims():
	var scene = load("res://scenes/Archer.tscn").instantiate()
	var p = _find_animation_player(scene)
	var text = ""
	if p:
		var libs = p.get_animation_library_list()
		for l in libs:
			var lib = p.get_animation_library(l)
			for a in lib.get_animation_list():
				text += str(l) + "/" + str(a) + "\n"
	
	var f = FileAccess.open("res://anims.txt", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	
func _find_animation_player(node: Node) -> AnimationPlayer:
	if not node: return null
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var res = _find_animation_player(child)
		if res: return res
	return null
