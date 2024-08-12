@tool
extends Node2D
class_name Leaf

@onready var spline: Spline2D = $spline

@export_range(10, 1000, 1, 'or_greater', 'or_less') var tail:float = 100.0:
  set(value):
    tail = value
    schedule_recalc()

@export_range(10, 1000, 1, 'or_greater', 'or_less') var body:float = 100.0:
  set(value):
    body = value
    schedule_recalc()

@export_range(10, 1000, 1, 'or_greater', 'or_less') var head:float = 100.0:
  set(value):
    head = value
    schedule_recalc()

@export_range(10, 1000, 1, 'or_greater') var width:float = 50.0:
  set(value):
    width = value
    schedule_recalc()

@export_range(1, 100, 1, 'or_greater') var pointy:float = 50.0:
  set(value):
    pointy = value
    schedule_recalc()

@export_range(-100, 100, 1, 'or_greater', 'or_less') var head_bias_left:float = 0.0:
  set(value):
    head_bias_left = value
    schedule_recalc()
@export_range(-100, 100, 1, 'or_greater', 'or_less') var head_bias_right:float = 0.0:
  set(value):
    head_bias_right = value
    schedule_recalc()

var _recalc_scheduled:bool
func schedule_recalc()->void:
  _recalc_scheduled = true

func _process(delta:float)->void:
  _recalc_scheduled = false
  recalc()

func recalc()->void:
  if !spline: return
  var points:PackedVector2Array = PackedVector2Array()
  points.resize(7)
  points[0] = Vector2(0, 0)
  points[6] = Vector2(0, 0)

  var y:float = tail
  var x:float = width
  points[1] = Vector2(x,y)
  points[5] = Vector2(-x,y)
  y += body
  points[2] = Vector2( x + head_bias_left, y + head_bias_left)
  points[4] = Vector2(-x - head_bias_right,y + head_bias_right)

  y += head
  points[3] = Vector2(0, y)

  var weights:PackedFloat32Array = PackedFloat32Array()
  weights.resize(7)
  weights.fill(1)
  weights[3] = pointy
  spline.set_points(points, weights)
