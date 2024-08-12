@tool
extends Node2D
class_name Ellipse

var points:PackedVector2Array = PackedVector2Array()

var _modified:bool = true

@export_range(16, 500) var num_points:int = 50:
  set(value):
    num_points = value
    queue_recalc()

@export_range(1, 1000, 1, 'or_greater') var width:float = 200.0:
  set(value):
    width = value
    queue_recalc()

@export_range(1, 1000, 1, 'or_greater') var height:float = 100.0:
  set(value):
    height = value
    queue_recalc()

@export var border_color:Color = Color.WHITE:
  set(value):
    border_color = value
    queue_redraw()

@export_range(0, 10, 1, 'or_greater') var border_width:float = 0.0:
  set(value):
    border_width = value
    queue_redraw()

@export var fill:bool = true:
  set(value):
    fill = value
    queue_redraw()

@export var fill_color:Color = Color.RED:
  set(value):
    fill_color = value
    queue_redraw()

func queue_recalc():
  _modified = true
  queue_redraw()

func _draw()->void:
  if _modified:
    _modified = false
    var dd = TAU / num_points as float
    points.resize(num_points + 1)
    for i in num_points:
      var a:float = dd * i as float
      var pos = Vector2(width * cos(a), height * sin(a))
      points[i] = pos
    points[num_points] = points[0]

  if fill:
    draw_colored_polygon(points, fill_color)
  if border_width > 0:
    draw_polyline(points, border_color, border_width)
