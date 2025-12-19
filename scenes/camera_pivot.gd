extends Node3D

const MOUSE_SENSITIVITY := 0.005
const ZOOM_LERP_SPEED := 8.0   # скорость сглаживания зума

@onready var vertical_pivot: Node3D = $CameraVerticalPivot
@onready var zoom_pivot: Node3D = $CameraVerticalPivot/CameraZoomPivot
@onready var camera: Camera3D = $CameraVerticalPivot/CameraZoomPivot/Camera3D

var pitch := 0.0
var target_distance := -1.0     # целевое расстояние камеры
var current_distance := -1.0    # текущая позиция для плавного зума
var min_distance := -0.3       # минимальное приближение
var max_distance := -2.0        # максимальное отдаление
var zoom_step := 0.5

var max_pitch := deg_to_rad(45)   # ограничение поворота вверх
var min_pitch := deg_to_rad(-45)  # ограничение поворота вниз

func _ready():
	zoom_pivot.position.z = current_distance

func _input(event: InputEvent) -> void:
	# Поворот камеры мышью
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY       # горизонтальный
		pitch += event.relative.y * MOUSE_SENSITIVITY           # вертикальный (инвертировано)
		pitch = clamp(pitch, min_pitch, max_pitch)
		vertical_pivot.rotation.x = pitch

	# Зум колесиком (меняем целевое расстояние)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance += zoom_step      # приближаем
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance -= zoom_step      # отдаляем
		target_distance = clamp(target_distance, max_distance, min_distance)

func _process(delta: float) -> void:
	# Плавно интерполируем расстояние камеры
	current_distance = lerp(current_distance, target_distance, ZOOM_LERP_SPEED * delta)
	zoom_pivot.position.z = current_distance
