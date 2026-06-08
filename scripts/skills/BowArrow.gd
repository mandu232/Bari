extends Area2D
class_name BowArrow

var direction:    Vector2 = Vector2.RIGHT
var speed:        float   = 650.0
var damage:       float   = 0.5
var max_range:    float   = 700.0
var pierce_count: int     = 2

var _traveled:   float = 0.0
var _hit_bodies: Array = []

func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step   := speed * delta
	position   += direction * step
	_traveled  += step
	if _traveled >= max_range:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	pierce_count -= 1
	if pierce_count <= 0:
		queue_free()
