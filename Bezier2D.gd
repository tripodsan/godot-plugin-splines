@tool
extends Node2D

@onready var path: Path2D = $path

@onready var poly: Polygon2D = $poly

@export var redraw:bool:
  set(value):
    redraw = false
    recalc()

@export var tesselate_even:bool = false:
  set(value):
    tesselate_even = value
    recalc()

@export_range(1, 10) var max_stages: int = 5:
  set(value):
    max_stages = value
    recalc()

@export_range(4, 40) var tolerance_degrees: float = 4:
  set(value):
    tolerance_degrees = value
    recalc()

@export_range(5, 100) var tolerance_length: float = 20:
  set(value):
    tolerance_length = value
    recalc()

var curve:Curve2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  curve = path.curve
  recalc()

func recalc():
  if tesselate_even:
    poly.polygon = curve.tessellate_even_length(max_stages, tolerance_length)
  else:
    poly.polygon = curve.tessellate(max_stages, tolerance_degrees)


