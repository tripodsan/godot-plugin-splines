@tool
extends Node2D

@onready var spline: Spline2D = $spline

var seed:float = 1234.5567

@export var size:Vector2 = Vector2(600, 200):
  set(value):
    size = value
    recalc()

@export_range(8, 100, 1, 'or_greater') var delta_x:int = 48:
  set(value):
    delta_x = value
    recalc()

@export var use_viewport_width:bool = true

@export var offset:int = 0:
  set(value):
    offset = value
    recalc()

var xxhash:XXHash

func _ready()->void:
  xxhash = XXHash.new(seed)
  recalc()

func _process(delta:float)->void:
  if Engine.is_editor_hint(): return
  var tx = get_viewport().canvas_transform;
  var x = -global_position.x if get_parent() is ParallaxLayer else -tx.origin.x
  var idx:int = round(x / delta_x)
  if idx != offset:
    offset = idx

func recalc()->void:
  if !spline:
    return
  var pts:PackedVector2Array = PackedVector2Array()
  var width = size.x
  if use_viewport_width && !Engine.is_editor_hint():
    width = get_viewport_rect().size.x
  var n:int = ceil(width / delta_x) + (spline.degree - 1) + 2
  pts.resize(n)
  for i in n:
    var xi = i - (spline.degree - 1) / 2.0 - 1
    var x:float = (xi + offset) * delta_x
    var y = xxhash.hash(xi + offset, 0) * size.y
    pts[i] = Vector2(x, y)
  spline.set_points(pts)
