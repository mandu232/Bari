extends Node
## AutoLoad 싱글톤
## Project > Project Settings > AutoLoad > Name: GameManager

# ───────────────────────────────
#  전역 데이터
# ───────────────────────────────
var echo_essence: int              = 9999
var total_echoes: int               = 0
var artifacts: Array[ArtifactData]   = []
var dungeon_depth: int               = 1
var current_run_active: bool         = false

var unlocked_blueprints: Array[BuildableItem] = []
var essence_rate: float = 0.0

# ───────────────────────────────
#  전력 (電力)
# ───────────────────────────────
var total_power: int = 0   # 발전소가 공급하는 총 전력
var used_power:  int = 0   # 구조물이 소비 중인 전력

# 플레이어 영구 스탯 (박물관 업그레이드로 증가)
var player_max_health: int           = 6
var player_damage_bonus: int         = 0
var player_speed_bonus: float        = 0.0

# ───────────────────────────────
#  씬 경로
# ───────────────────────────────
const MUSEUM_SCENE  := "res://scenes/Museum.tscn"
const DUNGEON_SCENE := "res://scenes/Dungeon.tscn"

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
signal essence_changed(new_value: int)
signal essence_rate_changed(rate: float)
signal power_changed(used: int, total: int)
signal artifact_added(artifact: ArtifactData)
signal echo_count_changed(count: int)
signal run_started(depth: int)
signal run_ended(success: bool)

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	load_game()
	var artifact = load("res://resources/artifacts/artifact_sword.tres")
	add_artifact(artifact)
	_init_starting_blueprints()

func _init_starting_blueprints() -> void:
	
	var stand := load("res://resources/buildables/artifact_stand.tres") as BuildableItem
	if stand:
		unlocked_blueprints.append(stand)

	var plant_1 := load("res://resources/buildables/power_plant_Lv1.tres") as BuildableItem
	if plant_1:
		unlocked_blueprints.append(plant_1)

	var plant_2 := load("res://resources/buildables/power_plant_Lv2.tres") as BuildableItem
	if plant_2:
		unlocked_blueprints.append(plant_2)

	var plant_3 := load("res://resources/buildables/power_plant_Lv3.tres") as BuildableItem
	if plant_3:
		unlocked_blueprints.append(plant_3)

	var powertower := load("res://resources/buildables/power_tower.tres") as BuildableItem
	if powertower:
		unlocked_blueprints.append(powertower)

# ───────────────────────────────
#  설계도
# ───────────────────────────────
func unlock_blueprint(item: BuildableItem) -> void:
	if item not in unlocked_blueprints:
		unlocked_blueprints.append(item)

func set_essence_rate(rate: float) -> void:
	essence_rate = rate
	essence_rate_changed.emit(rate)

# ───────────────────────────────
#  전력 관리
# ───────────────────────────────
## 발전소가 가동될 때 호출 — 공급 가능 전력 증가
func add_power_source(amount: int) -> void:
	total_power += amount
	power_changed.emit(used_power, total_power)

## 발전소가 제거될 때 호출 — 공급 가능 전력 감소
func remove_power_source(amount: int) -> void:
	total_power = max(0, total_power - amount)
	power_changed.emit(used_power, total_power)

## 구조물이 전력을 사용하려 할 때 호출
## 성공하면 true / 전력 부족이면 false
func try_consume_power(amount: int) -> bool:
	if amount == 0:
		return true
	if used_power + amount > total_power:
		return false
	used_power += amount
	power_changed.emit(used_power, total_power)
	return true

## 구조물이 제거될 때 사용하던 전력을 반환
func release_power(amount: int) -> void:
	if amount == 0:
		return
	used_power = max(0, used_power - amount)
	power_changed.emit(used_power, total_power)

## 씬 전환 시 전력 상태 초기화 (선택적 사용)
func reset_power() -> void:
	total_power = 0
	used_power  = 0

# ───────────────────────────────
#  영력 (靈力)
# ───────────────────────────────
func add_essence(amount: int) -> void:
	echo_essence += amount
	essence_changed.emit(echo_essence)

func spend_essence(amount: int) -> bool:
	if echo_essence < amount:
		return false
	echo_essence -= amount
	essence_changed.emit(echo_essence)
	return true

# ───────────────────────────────
#  유물
# ───────────────────────────────
func add_artifact(artifact: ArtifactData) -> void:
	artifacts.append(artifact)
	artifact_added.emit(artifact)

func remove_artifact(artifact: ArtifactData) -> void:
	artifacts.erase(artifact)

# ───────────────────────────────
#  혼 (魂)
# ───────────────────────────────
func add_echo(count: int = 1) -> void:
	total_echoes += count
	echo_count_changed.emit(total_echoes)

# ───────────────────────────────
#  씬 전환
# ───────────────────────────────
func start_dungeon_run() -> void:
	current_run_active = true
	run_started.emit(dungeon_depth)
	get_tree().change_scene_to_file(DUNGEON_SCENE)

func return_to_museum(run_success: bool = true) -> void:
	current_run_active = false
	if run_success:
		dungeon_depth += 1
	run_ended.emit(run_success)
	get_tree().change_scene_to_file(MUSEUM_SCENE)

# ───────────────────────────────
#  저장 / 불러오기
# ───────────────────────────────
const SAVE_PATH := "user://savegame.cfg"

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "essence",       echo_essence)
	cfg.set_value("player", "echoes",       total_echoes)
	cfg.set_value("player", "dungeon_depth", dungeon_depth)
	cfg.set_value("player", "max_health",    player_max_health)
	cfg.set_value("player", "damage_bonus",  player_damage_bonus)
	cfg.set_value("player", "speed_bonus",   player_speed_bonus)
	cfg.save(SAVE_PATH)

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	echo_essence      = cfg.get_value("player", "essence",       0)
	total_echoes       = cfg.get_value("player", "echoes",       0)
	dungeon_depth       = cfg.get_value("player", "dungeon_depth", 1)
	player_max_health   = cfg.get_value("player", "max_health",    6)
	player_damage_bonus = cfg.get_value("player", "damage_bonus",  0)
	player_speed_bonus  = cfg.get_value("player", "speed_bonus",   0.0)
