extends Node

var selected_ant := 0
var demo_mode := false
var poison_damage := 1
var attack_cooldown := 0.42
var player_speed := 125.0
var max_health := 3
var poison_duration := 1.4

func reset_run() -> void:
	poison_damage = 1
	attack_cooldown = 0.42
	player_speed = 125.0
	max_health = 3
	poison_duration = 1.4
