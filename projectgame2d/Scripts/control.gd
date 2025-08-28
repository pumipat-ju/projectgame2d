extends Control

@export var red_scene: PackedScene
@export var blue_scene: PackedScene

const LEVEL_01_PATH := "res://Scenes/Levels/Level_01.tscn"

#func _ready():
	## ถ้ายังไม่ได้ต่อสัญญาณผ่าน Inspector โค้ดนี้จะเชื่อมให้
	#$"Red".pressed.connect(_on_red_pressed)
	#$"Blue".pressed.connect(_on_blue_pressed)

func _on_red_pressed():
	_choose_and_go(red_scene)

func _on_blue_pressed():
	_choose_and_go(blue_scene)

func _choose_and_go(scene: PackedScene) -> void:
	if scene == null:
		push_warning("Selected scene is null. Drag Red.tscn/Blue.tscn into exported fields.")
		return
	GameManager.selected_player_scene = scene
	get_tree().change_scene_to_file(LEVEL_01_PATH)
