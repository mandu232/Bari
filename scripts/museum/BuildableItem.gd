extends Resource
class_name BuildableItem

@export_group("기본 정보")
@export var item_name:   String      = "이름 없음"
@export var description: String      = ""
@export var icon:        Texture2D   = null

@export_group("건설")
@export var scene:       PackedScene = null
@export var cost:        int         = 20

@export_group("전력")
@export var power_consumption: int   = 0     # 이 구조물이 소비하는 전력
@export var power_output:      int   = 0     # 이 구조물이 공급하는 전력 (발전소 전용)
@export var power_range:       float = 0.0   # 전력 공급/출력 반경 (0 = 스크립트 기본값 사용)
@export var relay_capacity:    int   = 0     # 최대 중계 전력량 (송전탑 전용, 0 = 스크립트 기본값)
@export var chain_range:       float = 0.0   # 수동 배선 최대 거리 (송전탑 전용, 0 = 스크립트 기본값)
