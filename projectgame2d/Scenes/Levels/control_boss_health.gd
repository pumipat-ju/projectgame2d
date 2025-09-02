extends Control

@onready var score_label = %Score/ScoreLabel
@onready var kill_label = $KillLabel
@onready var player_health_bar = $PlayerHealthBar
@onready var boss_health_bar = $BossHealthBar
@onready var death_label = $DeathLabel

func _process(_delta):
	# คะแนน
	score_label.text = "x %d" % GameManager.score
	# จำนวนที่ฆ่า
	kill_label.text = "Kills: %d" % GameManager.kill_count
	# จำนวนครั้งที่ตาย
	death_label.text = "Deaths: %d" % GameManager.player_deaths
	# เลือดผู้เล่น
	player_health_bar.max_value = GameManager.player_max_health
	player_health_bar.value = GameManager.player_health
	# เลือดบอส
	if GameManager.boss_health >= 0:
		boss_health_bar.visible = true
		boss_health_bar.max_value = GameManager.boss_max_health
		boss_health_bar.value = GameManager.boss_health
