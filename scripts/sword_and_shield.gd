extends Area3D

func _input(event):
	# Проверяем нажатие локально
	if event.is_action_pressed("E"):
		var bodies = get_overlapping_bodies()
		for body in bodies:
			# Проверка 1: Это Воин?
			# Проверка 2: Это МОЙ персонаж (authority)?
			# Проверка 3: У него еще нет оружия?
			if body is WarriorPlayer and body.is_multiplayer_authority() and not body.has_weapons:
				# Вызываем удаление меча у всех через сервер
				_remove_sword_globally.rpc()
				# Даем оружие персонажу
				body.pickup_weapons()
				break

@rpc("any_peer", "call_local", "reliable")
func _remove_sword_globally():
	queue_free()
