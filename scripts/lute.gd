extends Node3D

# Полная раскладка (A-L и Z-X)
var input_to_note = {
	KEY_Z: "a2", KEY_X: "b2",
	KEY_A: "c3", KEY_S: "d3", KEY_D: "e3", 
	KEY_F: "f3", KEY_G: "g3", KEY_H: "a3", KEY_J: "b3",
	KEY_K: "c4", KEY_L: "d4" 
}

var note_players = {}

func _ready():
	# Список всех возможных имен префиксов
	var notes = ["a2", "b2", "a3", "b3", "c3", "d3", "e3", "f3", "g3", "c4", "d4"]
	
	for n_name in notes:
		note_players[n_name] = []
		
		# Проверяем все варианты: имя_1, имя_2 или просто имя
		var variants = [n_name + "_1.wav", n_name + "_2.wav", n_name + ".wav"]
		
		for file_name in variants:
			var path = "res://sound/Notes/" + file_name
			if FileAccess.file_exists(path):
				var p = AudioStreamPlayer.new() # Обычный плеер часто работает быстрее 3D
				p.stream = load(path)
				add_child(p)
				note_players[n_name].append(p)
				
		if note_players[n_name].size() == 0:
			print("Пропуск ноты (файл не найден): ", n_name)

func _input(event):
	if not is_multiplayer_authority(): return
	
	# Проверка: включен ли режим музыки у игрока
	var player_parent = get_parent()
	if not player_parent or not player_parent.has_property("is_playing_music") or not player_parent.is_playing_music:
		return 

	if event is InputEventKey and event.pressed and not event.is_echo():
		if input_to_note.has(event.keycode):
			# Говорим Godot, что мы обработали это нажатие (чтобы игрок не дергался)
			get_viewport().set_input_as_handled() 
			play_note.rpc(input_to_note[event.keycode])

@rpc("any_peer", "call_local")
func play_note(n_name):
	if note_players.has(n_name) and note_players[n_name].size() > 0:
		var p = note_players[n_name].pick_random()
		p.stop() # Остановка текущего звука перед новым дает четкий "клик"
		p.play()
