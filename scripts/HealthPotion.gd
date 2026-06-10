extends Area2D
class_name HealthPotion

const HEAL_AMOUNT := 2
const TEXTURE := preload("res://AutoLoad/assets/Item/heal_item.png")

var _collected:  bool  = false
var _attracting: bool  = false
var _float_time: float = 0.0
var _sprite: Sprite2D
var _col:    CollisionShape2D

func _ready() -> void:
	set_process(false)   # 착지 전까지 비활성

	_sprite         = Sprite2D.new()
	_sprite.texture = TEXTURE
	add_child(_sprite)

	_col          = CollisionShape2D.new()
	var circ      := CircleShape2D.new()
	circ.radius   = 18.0
	_col.shape    = circ
	_col.disabled = true
	add_child(_col)

	collision_layer = 0
	collision_mask  = 0
	body_entered.connect(_on_body_entered)

# 포물선 착지 후 호출
func land() -> void:
	set_process(true)
	_col.set_deferred("disabled", false)
	collision_mask = 1
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", Vector2.ONE,       0.10).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _collected:
		return
	z_as_relative = false
	z_index       = int(global_position.y) + 1
	_float_time        += delta * 2.6
	_sprite.position.y  = sin(_float_time) * 3.5

	if _attracting:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(player):
			var diff := player.global_position - global_position
			if diff.length() < 12.0:
				_collect()
				return
			var spd := lerpf(180.0, 440.0, 1.0 - clampf(diff.length() / 60.0, 0.0, 1.0))
			global_position += diff.normalized() * spd * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _collected:
		_attracting = true

func _collect() -> void:
	if _collected:
		return
	_collected = true
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("heal"):
		player.heal(HEAL_AMOUNT)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale",      Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(self,    "modulate:a", 0.0,          0.12)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
