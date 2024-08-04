@tool
extends Node2D

@onready var points_poly: Polygon2D = $points_poly
@onready var poly: Polygon2D = $poly
@onready var line: Line2D = $line

## Degree of B-Spline (eg 3 for cubic)
@export_range(1, 5) var degree:int = 3:
  set(value):
    degree = value
    update_shape()

## Detail
@export var detail:int = 20:
  set(value):
    detail = value
    update_shape()

@export var open:bool = false:
  set(value):
    open = value
    update_shape()

@export var clamped:bool = false:
  set(value):
    clamped = value
    update_shape()

@export var redraw:bool:
  set(value):
    redraw = false
    update_shape()

func update_shape():
  var c:float = detail - 1
  var points = points_poly.polygon;
  if !open:
    points = points.duplicate()
    points.append_array(points.slice(0, degree + 1))
  var size = points.size()
  var knots:PackedFloat32Array = Spline2D.create_uniform_knots(size, degree, clamped)
  var weights:PackedFloat32Array = Spline2D.create_uniform_weights(size)
  var pts:PackedVector2Array = PackedVector2Array()

  var maxT = 1.0
  if !open:
    maxT = 1.0 - 1.0 / (size - degree)

  pts.resize(detail)
  for n in detail:
    pts[n] = Spline2D.interpolate(maxT * n / c, degree, points, knots, weights)
  if open:
    line.points = pts
  else:
    poly.polygon = pts
  line.visible = open
  poly.visible = !open
