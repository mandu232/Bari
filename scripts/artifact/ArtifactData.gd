extends Resource
class_name ArtifactData

@export_group("기본 정보")
@export var artifact_name: String       = "이름 없는 유물"
@export var description: String         = ""
@export var texture: Texture2D          = null   # 전시대 위에 표시될 스프라이트

@export_group("혼(魂) 정보")
@export var spirit_name: String            = "이름 없는 혼"
@export var spirit_frames: SpriteFrames   = null   # 혼 프레임
@export var spirit_power: int              = 1      # 혼의 강도 (던전 버프 등에 사용)
@export var wander_radius: float           = 64.0   # 전시대 주변 배회 반경

@export_group("효과")
@export var essence_per_second: float   = 0.5    # 초당 영력 생성량
@export var passive_description: String = ""     # 패시브 효과 설명 (UI 표시용)
