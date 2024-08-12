@tool
extends Node2D
class_name Flower

@onready var scnSimpleLeaf:PackedScene = preload('res://SimpleLeaf.tscn')

@onready var stem: Spline2D = $stem
@onready var leaves: Node2D = $leaves
@onready var head: FlowerHead = $head

var xxhash:XXHash = XXHash.new()

@export_category('Stem')
@export var seed:int=0:
  set(value):
    seed = value
    xxhash = XXHash.new(seed)
    recalc()


@export_range(10, 1000, 1, 'or_greater') var height:float = 400.0:
  set(value):
    height = value
    recalc()

@export_range(10, 1000, 1, 'or_greater') var width:float = 50.0:
  set(value):
    width = value
    recalc()

## Defines the number of 'curves' the stem has. The Spline control points will alternate left and right the main stem this number of times.
@export_range(2, 10, 1, 'or_greater') var num_stem_curves:int = 2:
  set(value):
    num_stem_curves = value
    recalc()

@export_category('Leaves')
@export_range(0, 10, 1, 'or_greater') var num_leaves:int = 2:
  set(value):
    num_leaves = value
    recalc()

@export_range(0, 10, 1, 'or_greater') var leaf_spacing:float = 100.0:
  set(value):
    leaf_spacing = value
    recalc()

@export_range(0, 10, 1, 'or_greater') var leaf_offset:float = 50.0:
  set(value):
    leaf_offset = value
    recalc()

@export var alternate_leaves:bool = false:
  set(value):
    alternate_leaves = value
    recalc()

@export_range(0, 360, 1, 'suffix:°') var leaf_rotation:float = 60.0:
  set(value):
    leaf_rotation = value
    recalc()
@export_range(0, 360, 1, 'suffix:°') var leaf_rotation_variation:float = 10.0:
  set(value):
    leaf_rotation_variation = value
    recalc()

@export_range(-100, 100, 1, 'or_greater', 'or_less') var leaf_head_bias:float = 0.0:
  set(value):
    leaf_head_bias = value
    recalc()

@export_range(10, 1000, 1, 'or_greater', 'or_less') var leaf_tail:float = 100.0:
  set(value):
    leaf_tail = value
    recalc()

@export_range(10, 1000, 1, 'or_greater', 'or_less') var leaf_body:float = 100.0:
  set(value):
    leaf_body = value
    recalc()

@export_range(10, 1000, 1, 'or_greater', 'or_less') var leaf_head:float = 100.0:
  set(value):
    leaf_head = value
    recalc()

@export_range(10, 1000, 1, 'or_greater') var leaf_width:float = 50.0:
  set(value):
    leaf_width = value
    recalc()

@export_range(1, 100, 1, 'or_greater') var leaf_pointy:float = 50.0:
  set(value):
    leaf_pointy = value
    recalc()

enum RAND { CURVE_DIR, CURVE_WIDTH, LEAF_ROTATION }

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

func recalc()->void:
  if !stem: return
  # update stem
  var stem_points:PackedVector2Array = PackedVector2Array()
  stem_points.push_back(Vector2.ZERO)
  var delta:float = height / (num_stem_curves + 1)
  var dir = 1 if xxhash.hash(0, RAND.CURVE_DIR) < 0.5 else -1
  for i in num_stem_curves:
    var y = -(i + 1) * delta
    var x = lerp(width / 2, width, xxhash.hash(i, RAND.CURVE_WIDTH)) * dir
    stem_points.push_back(Vector2(x, y))
    dir *= -1
  var top = Vector2(0, -height)
  stem_points.push_back(top)
  head.position = top
  stem.set_points(stem_points)

  # update leaves
  var d = leaves.get_child_count() - num_leaves
  while d > 0:
    d -= 1
    leaves.remove_child(leaves.get_child(0))
  while d < 0:
    d += 1
    var leaf:Leaf = scnSimpleLeaf.instantiate()
    leaf.name = 'leaf'
    leaves.add_child(leaf)
    leaf.set_owner(owner)
    leaf.show()

  if num_leaves > 0:
    dir = 1
    for i in num_leaves:
      var leaf:Leaf = leaves.get_child(i)
      var step:int = i if alternate_leaves else i / 2
      var pos:Vector2 = Vector2(0, -(step + 1) * leaf_spacing - leaf_offset)
      pos = stem.get_closest_curve_point(pos)
      leaf.position = pos

      var rv = xxhash.hash(i, RAND.LEAF_ROTATION) * leaf_rotation_variation - leaf_rotation_variation / 2.0
      leaf.rotation_degrees = leaf_rotation * dir + rv
      if dir == 1:
        leaf.head_bias_left = leaf_head_bias
        leaf.head_bias_right = 0
      else:
        leaf.head_bias_right = leaf_head_bias
        leaf.head_bias_left = 0
      leaf.head = leaf_head
      leaf.body = leaf_body
      leaf.tail = leaf_tail
      leaf.pointy = leaf_pointy
      leaf.width = leaf_width
      dir *= -1


