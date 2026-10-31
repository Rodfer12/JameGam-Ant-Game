extends Node

## Autoload. Holds the persistent profile (amber, permanent upgrades, records),
## the state of the current run, and every derived combat stat. Stats are always
## recomputed from scratch from ant + permanent upgrades + run upgrades, so
## nothing can drift out of sync.

const SAVE_PATH := "user://silly_ant_save.cfg"

# --- Persistent profile --------------------------------------------------------
var amber := 0
var meta_levels: Dictionary = {}
var best_floor := 0
var best_score := 0
var total_runs := 0
var total_wins := 0
var total_kills := 0

# --- Session -------------------------------------------------------------------
var selected_ant := 0
var demo_mode := false

# --- Current run -----------------------------------------------------------------
var run_upgrades: Dictionary = {}
var run_floor := 1
var run_amber := 0
var run_score := 0
var run_kills := 0
var run_rooms := 0
var run_time := 0.0
var run_best_combo := 0

# --- Derived stats ---------------------------------------------------------------
var max_health := 6
var armor_max := 0
var player_speed := 125.0
var spit_damage := 2.0
var spit_cooldown := 0.42
var spit_count := 1
var spit_pierce := 0
var spit_bounce := 0
var poison_power := 1.0
var poison_duration := 1.4
var poison_stack_cap := 3
var poison_spread := 0
var caustic := 0
var bite_damage := 4.0
var bite_cooldown := 0.55
var bite_range := 40.0
var bite_arc := 1.05
var bite_leech := 0.0
var bite_reflect := false
var execute_fraction := 0.0
var dash_cooldown := 1.1
var dash_charges := 1
var trail_level := 0
var crit_chance := 0.05
var crit_mult := 2.0
var thorns := 0
var magnet_range := 60.0
var amber_mult := 1.0
var luck := 0.0
var berserk := false
var combo_bonus := 0.0
var second_wind := false


func _ready() -> void:
	load_game()
	recompute_stats()


# --- Lookups -----------------------------------------------------------------------

func upgrade_level(id: String) -> int:
	return int(run_upgrades.get(id, 0))


func meta_level(id: String) -> int:
	return int(meta_levels.get(id, 0))


func ant_data() -> Dictionary:
	return GameData.ANTS[clampi(selected_ant, 0, GameData.ANTS.size() - 1)]


func find_upgrade(id: String) -> Dictionary:
	for u in GameData.UPGRADES:
		if str(u["id"]) == id:
			return u
	return {}


# --- Stats ---------------------------------------------------------------------------

func recompute_stats() -> void:
	var ant := ant_data()
	var l_hp := upgrade_level("carapace")
	max_health = maxi(1, 6 + meta_level("hp") + int(ant.get("hp", 0)) + 2 * l_hp)
	armor_max = maxi(0, int(ant.get("armor", 0)) + 2 * upgrade_level("plates"))
	player_speed = 125.0 * (1.0 + 0.04 * float(meta_level("speed")) + 0.10 * float(upgrade_level("legs")) + float(ant.get("speed", 0.0)))

	spit_damage = maxf(1.0, 2.0 + float(meta_level("venom")) + float(ant.get("spit", 0.0)) + float(upgrade_level("gland")))
	spit_cooldown = maxf(0.14, 0.42 * pow(0.88, float(upgrade_level("fangs"))))
	spit_count = 1 + upgrade_level("twin")
	spit_pierce = upgrade_level("pierce")
	spit_bounce = upgrade_level("ricochet")

	var virulent := upgrade_level("virulent")
	poison_power = 1.0 + 0.5 * float(virulent)
	poison_stack_cap = 3 + 2 * virulent
	poison_duration = (1.4 + 0.8 * float(upgrade_level("venom"))) * (1.0 + float(ant.get("poison", 0.0)))
	poison_spread = upgrade_level("plague")
	caustic = upgrade_level("boom")

	bite_damage = maxf(1.0, 4.0 + float(ant.get("bite", 0.0)) + 2.0 * float(upgrade_level("mandibles")))
	bite_cooldown = 0.55
	bite_range = 40.0
	bite_arc = 1.05
	bite_leech = 0.35 * float(upgrade_level("vampiric"))
	bite_reflect = upgrade_level("deflector") > 0
	var exec_table: Array[float] = [0.0, 0.25, 0.4]
	execute_fraction = exec_table[clampi(upgrade_level("exec"), 0, 2)]

	dash_cooldown = 1.1 * pow(0.85, float(upgrade_level("lunge")))
	dash_charges = 1 + upgrade_level("double")
	trail_level = upgrade_level("trail")

	crit_chance = clampf(0.05 + 0.06 * float(upgrade_level("eyes")) + float(ant.get("crit", 0.0)), 0.0, 0.8)
	crit_mult = 2.0
	thorns = upgrade_level("thorns")
	magnet_range = 60.0 * (1.0 + 0.5 * float(upgrade_level("magnet")))
	amber_mult = 1.0 + 0.15 * float(upgrade_level("magnet")) + 0.10 * float(meta_level("nose")) + float(ant.get("amber", 0.0))
	luck = 0.1 * float(meta_level("favor"))
	berserk = upgrade_level("rage") > 0
	combo_bonus = 0.01 * float(upgrade_level("adrenaline"))
	second_wind = upgrade_level("wind") > 0 or meta_level("wind") > 0


# --- Run lifecycle ---------------------------------------------------------------------

func reset_run() -> void:
	run_upgrades.clear()
	run_floor = 1
	run_amber = 0
	run_score = 0
	run_kills = 0
	run_rooms = 0
	run_time = 0.0
	run_best_combo = 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var commons: Array[String] = []
	for u in GameData.UPGRADES:
		if int(u["rarity"]) == 0 and not bool(u.get("instant", false)):
			commons.append(str(u["id"]))
	for i in meta_level("pack"):
		if commons.is_empty():
			break
		add_upgrade(commons[rng.randi_range(0, commons.size() - 1)])
	recompute_stats()


func add_upgrade(id: String) -> void:
	run_upgrades[id] = upgrade_level(id) + 1


## Banks the run into the permanent profile. Returns {"gained", "new_best"}.
func bank_run(victory: bool) -> Dictionary:
	var gained := run_amber + (150 if victory else 0)
	var new_best := run_score > best_score
	amber += gained
	total_runs += 1
	if victory:
		total_wins += 1
	total_kills += run_kills
	best_floor = maxi(best_floor, run_floor)
	best_score = maxi(best_score, run_score)
	save_game()
	return {"gained": gained, "new_best": new_best}


# --- Colony Hall -------------------------------------------------------------------------

func meta_cost(entry: Dictionary) -> int:
	return int(entry["cost"]) * (meta_level(str(entry["id"])) + 1)


func buy_meta(id: String) -> bool:
	for entry in GameData.META:
		if str(entry["id"]) != id:
			continue
		var level := meta_level(id)
		if level >= int(entry["max"]):
			return false
		var cost := meta_cost(entry)
		if amber < cost:
			return false
		amber -= cost
		meta_levels[id] = level + 1
		save_game()
		recompute_stats()
		return true
	return false


# --- Save / load ---------------------------------------------------------------------------

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "amber", amber)
	cfg.set_value("profile", "meta_levels", meta_levels)
	cfg.set_value("profile", "best_floor", best_floor)
	cfg.set_value("profile", "best_score", best_score)
	cfg.set_value("profile", "total_runs", total_runs)
	cfg.set_value("profile", "total_wins", total_wins)
	cfg.set_value("profile", "total_kills", total_kills)
	cfg.set_value("profile", "selected_ant", selected_ant)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	amber = int(cfg.get_value("profile", "amber", 0))
	var stored: Variant = cfg.get_value("profile", "meta_levels", {})
	if stored is Dictionary:
		meta_levels = stored
	best_floor = int(cfg.get_value("profile", "best_floor", 0))
	best_score = int(cfg.get_value("profile", "best_score", 0))
	total_runs = int(cfg.get_value("profile", "total_runs", 0))
	total_wins = int(cfg.get_value("profile", "total_wins", 0))
	total_kills = int(cfg.get_value("profile", "total_kills", 0))
	selected_ant = clampi(int(cfg.get_value("profile", "selected_ant", 0)), 0, GameData.ANTS.size() - 1)
