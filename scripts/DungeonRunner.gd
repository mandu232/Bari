extends Node
## 던전 런 관리자 (AutoLoad: DungeonRunner)
## 깊이(depth)에 따라 방 풀에서 랜덤으로 골라 순서대로 로드
##
## 새 방 씬을 만들면 ROOM_POOLS의 해당 티어 배열에 경로를 추가하면 됩니다.

# ── 한 런에 이동할 방 수
const ROOMS_PER_RUN := 3

# ── 방 풀: 깊이 티어별 씬 경로 목록
# ※ DungeonRoom 씬은 Dungeon.tscn을 복제해 AutoLoad/scenes/rooms/ 에 저장
const ROOM_POOLS: Dictionary = {
	1: [  # depth 1-3 (입문)
		"res://AutoLoad/scenes/Dungeon.tscn",  # 임시: 추후 개별 방으로 교체
	],
	2: [  # depth 4-6 (중급)
		"res://AutoLoad/scenes/Dungeon.tscn",
	],
	3: [  # depth 7+ (고급)
		"res://AutoLoad/scenes/Dungeon.tscn",
	],
}

var _run_queue:    Array[String] = []
var _current_idx:  int          = -1
var _run_active:   bool         = false

## 방 입장 시 발생 — HUD 진행도 표시용 (현재 방 번호, 총 방 수)
signal room_entered(room_num: int, total: int)

# ────────────────────────────────────────
#  런 시작 — GameManager.start_dungeon_run에서 호출
# ────────────────────────────────────────
func start_run() -> void:
	_current_idx = 0
	_run_queue   = _build_queue(GameManager.dungeon_depth)
	_run_active  = true
	_load_room(_run_queue[0])
	room_entered.emit(1, _run_queue.size())

# ────────────────────────────────────────
#  다음 방 — DungeonDoor._enter_next_stage에서 호출
# ────────────────────────────────────────
func next_room() -> void:
	_current_idx += 1
	if _current_idx >= _run_queue.size():
		_finish_run()
		return
	_load_room(_run_queue[_current_idx])
	room_entered.emit(_current_idx + 1, _run_queue.size())

# ────────────────────────────────────────
#  진행도 조회
# ────────────────────────────────────────
func get_progress() -> Dictionary:
	return {
		"current": _current_idx + 1,
		"total":   _run_queue.size(),
		"is_last": _current_idx >= _run_queue.size() - 1,
	}

func is_last_room() -> bool:
	return _current_idx >= _run_queue.size() - 1

# ────────────────────────────────────────
#  내부
# ────────────────────────────────────────
func _load_room(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _finish_run() -> void:
	_run_active = false
	_run_queue.clear()
	_current_idx = -1
	GameManager.return_to_museum(true)

func _build_queue(depth: int) -> Array[String]:
	var tier := _depth_to_tier(depth)
	var pool: Array = ROOM_POOLS.get(tier, ROOM_POOLS[1]).duplicate()

	# 풀이 ROOMS_PER_RUN보다 작을 경우 반복으로 채움
	while pool.size() < ROOMS_PER_RUN:
		pool.append_array(ROOM_POOLS.get(tier, ROOM_POOLS[1]))

	pool.shuffle()
	var queue: Array[String] = []
	for i in ROOMS_PER_RUN:
		queue.append(pool[i])
	return queue

func _depth_to_tier(depth: int) -> int:
	if depth <= 3:
		return 1
	if depth <= 6:
		return 2
	return 3
