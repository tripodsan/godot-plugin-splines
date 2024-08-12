@tool
extends Node2D
class_name FlowerHead

#---------------------------------------------------------------------------------------------
class Petal:
  var points:PackedVector2Array = PackedVector2Array()

  func calc(width:float, height:float, num_points:int = 50)->void:
    var dd = TAU / num_points as float
    points.resize(num_points + 1)
    for i in num_points:
      var a:float = dd * i as float
      var pos = Vector2(width * cos(a), -height * sin(a))
      points[i] = pos
    points[num_points] = points[0]

#---------------------------------------------------------------------------------------------

var petal:Petal = Petal.new()

var _modified:bool = false

@export_range(3, 20, 1, 'or_greater') var num_petals:=5:
  set(value):
    num_petals = value
    queue_recalc()

@export_range(1, 1000, 1, 'or_greater') var petal_distance:float = 50.0:
  set(value):
    petal_distance = value
    queue_redraw()

@export_range(1, 1000, 1, 'or_greater') var petal_width:float = 200.0:
  set(value):
    petal_width = value
    queue_recalc()

@export_range(1, 1000, 1, 'or_greater') var petal_height:float = 100.0:
  set(value):
    petal_height = value
    queue_recalc()

@export var petal_border_color:Color = Color.WHITE:
  set(value):
    petal_border_color = value
    queue_redraw()

@export_range(0, 10, 1, 'or_greater') var petal_border_width:float = 0.0:
  set(value):
    petal_border_width = value
    queue_redraw()

@export var petal_fill:bool = true:
  set(value):
    petal_fill = value
    queue_redraw()

@export var petal_fill_color:Color = Color.RED:
  set(value):
    petal_fill_color = value
    queue_redraw()

@export_range(0, 100, 1, 'or_greater') var inner_radius:float = 50.0:
  set(value):
    inner_radius = value
    queue_redraw()

@export var inner_fill_color:Color = Color.YELLOW:
  set(value):
    inner_fill_color = value
    queue_redraw()

@export var inner_border_color:Color = Color.WHITE:
  set(value):
    inner_border_color = value
    queue_redraw()

@export_range(0, 10, 1, 'or_greater') var inner_border_width:float = 0.0:
  set(value):
    inner_border_width = value
    queue_redraw()


func queue_recalc():
  _modified = true
  queue_redraw()

func _draw()->void:
  if _modified:
    _modified = false
    petal.calc(petal_height, petal_width)

  var dr:float = TAU / num_petals as float
  var dv = Vector2(petal_height / 2.0 + petal_distance, 0)
  for i in num_petals:
    var xform:Transform2D = Transform2D.IDENTITY.translated(dv).rotated(dr * i)
    draw_set_transform_matrix(xform)
    if petal_fill:
      draw_colored_polygon(petal.points, petal_fill_color)
    if petal_border_width > 0:
      draw_polyline(petal.points, petal_border_color, petal_border_width)

  # draw half of first again
  if petal_border_width > 0 && petal_fill:
    var pts = petal.points.slice(0, petal.points.size() / 2 + 1)
    var xform:Transform2D = Transform2D.IDENTITY.translated(dv)
    draw_set_transform_matrix(xform)
    draw_colored_polygon(pts, petal_fill_color)
    draw_polyline(pts, petal_border_color, petal_border_width)

  draw_set_transform_matrix(Transform2D.IDENTITY)
  if inner_radius > 0:
    draw_circle(Vector2.ZERO, inner_radius, inner_fill_color)
  if inner_border_width:
    draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 50, inner_border_color, inner_border_width)
