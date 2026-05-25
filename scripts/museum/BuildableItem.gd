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
@export var power_range:       float = 150.0 # 전력 공급 반경 (발전소 전용, 0 = 기본값 사용)
