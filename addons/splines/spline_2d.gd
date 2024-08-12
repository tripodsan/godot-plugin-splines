@tool
extends Node2D
class_name Spline2D

signal shape_updated()

## cached interpolated points
var interpolated_points:PackedVector2Array

## Control Points
@export var points:PackedVector2Array = PackedVector2Array()

## Weights
@export var weights:PackedFloat32Array = PackedFloat32Array()

## Auto updated collision polygon
@export_node_path('CollisionPolygon2D') var collision_poly:NodePath

## Degree of B-Spline (eg 3 for cubic)
@export_range(1, 5) var degree:int = 3:
  set(value):
    degree = value
    update_shape()

## Detail
@export var detail:int = 5:
  set(value):
    detail = value
    update_shape()

@export var open:bool = true:
  set(value):
    open = value
    update_shape()

@export var clamped:bool = true:
  set(value):
    clamped = value
    update_shape()


@export_group('Border')
@export var border:bool = true:
  set(value):
    border = value
    queue_redraw()

@export_range(-1, 10, 0.1, 'or_greater') var border_width:float = 2:
  set(value):
    border_width = value
    queue_redraw()

@export var border_color:Color = Color.WHITE:
  set(value):
    border_color = value
    queue_redraw()

@export_group('Fill')
@export var fill:bool = false:
  set(value):
    fill = value
    queue_redraw()

@export var fill_color:Color = Color.POWDER_BLUE:
  set(value):
    fill_color = value
    queue_redraw()

@export var fill_texture:Texture2D:
  set(value):
    fill_texture = value
    queue_redraw()

@export_group('Extend')

## The minimal bottom (y) value to extend an open shape
@export_range(0, 1000, 1, 'suffix:px', 'or_greater', 'or_less') var min_bottom:int = 0:
  set(value):
    min_bottom = value
    update_shape()

## The minimal top (y) value to extend an open shape
@export_range(0, 1000, 1, 'suffix:px', 'or_greater', 'or_less') var min_top:int = 0:
  set(value):
    min_top = value
    update_shape()

# -------------------------------------------------------------------------
func _ready() -> void:
  update_shape()

func add_point(p:Vector2)->void:
  points.append(p)
  weights.append(1.0)
  print_debug('add point %s (size=%d)' % [p, points.size()])
  update_shape()

func insert_point(p:Vector2, idx:int)->void:
  points.insert(idx, p)
  weights.insert(idx, 1.0)
  print_debug('insert point %s at %d (size=%d)' % [p, idx, points.size()])
  update_shape()

func set_point(idx:int, p:Vector2)->void:
  points[idx] = p
  #print_debug('set point %s at %d' % [p, idx])
  update_shape()

func set_points(pts:PackedVector2Array, w = null)->void:
  points = pts
  if w is PackedFloat32Array:
    weights = w
    update_shape()
  else:
    reset_weights()

func set_weight(idx:int, w:float)->void:
  weights[idx] = w
  #print_debug('set weight %f at %d' % [w, idx])
  update_shape()

func remove_point(idx:int)->void:
  points.remove_at(idx)
  weights.remove_at(idx)
  print_debug('removed point at %d (size=%d)' % [idx, points.size()])
  update_shape()

func clear_points()->void:
  points.clear()
  weights.clear()
  interpolated_points.clear()
  update_collision_polygon()
  print_debug('clear points')
  queue_redraw()

func reset_weights()->void:
  weights.resize(points.size())
  weights.fill(1)
  #print_debug('reset weights')
  update_shape()

func set_pivot(p:Vector2)->void:
  for i in points.size():
    points[i] -= p
  print_debug('set pivot')
  update_shape()

func create_collision_polygon()->void:
  if collision_poly:
    printerr('Collision polygon already exists.')
    return
  # assume if no poly exists, then also no static body exists
  var body:StaticBody2D = StaticBody2D.new()
  body.name = "StaticBody2D"
  var col_poly:CollisionPolygon2D = CollisionPolygon2D.new()
  col_poly.name = "CollisionPolygon2D"
  body.add_child(col_poly)
  add_child(body)
  body.set_owner(owner)
  col_poly.set_owner(owner)
  col_poly.polygon = interpolated_points
  collision_poly = get_path_to(col_poly)

func update_collision_polygon()->void:
  if !collision_poly: return
  var poly:CollisionPolygon2D = get_node(collision_poly)
  if !poly: return
  poly.polygon = interpolated_points


func get_closest_point(p: Vector2)->Dictionary:
  if points.size() < 3:
    return {
      'point': Vector2.ZERO,
      'idx': -1,
      'd': INF
    }
  var best
  var best_idx:int = -1
  var best_dist:float = INF
  var n:int = points.size();
  for i in (n - 1 if open else n):
    var ct = Geometry2D.get_closest_point_to_segment(p, points[i], points[(i + 1) % points.size()])
    var d = p.distance_squared_to(ct)
    if d < best_dist:
      best_dist = d
      best = ct
      best_idx = i
  return {
    'point': best,
    'idx': best_idx,
    'd': sqrt(best_dist)
  }

func get_closest_curve_point(p: Vector2)->Vector2:
  if interpolated_points.size() < 2:
    return p;
  var best
  var best_dist:float = INF
  var n:int = interpolated_points.size();
  for i in (n - 1 if open else n):
    var ct = Geometry2D.get_closest_point_to_segment(p, interpolated_points[i], interpolated_points[(i + 1) % interpolated_points.size()])
    var d = p.distance_squared_to(ct)
    if d < best_dist:
      best_dist = d
      best = ct
  return best

func update_shape():
  if !is_node_ready(): return
  assert(degree < points.size(), 'degree must be less than or equal to point count - 1')

  var steps = detail * points.size()
  var c:float = steps - 1
  var c_points = points
  var c_weights = weights
  if !open:
    c_points = c_points.duplicate()
    c_points.append_array(c_points.slice(0, degree + 1))
    c_weights.append_array(c_weights.slice(0, degree + 1))
  var size = c_points.size()
  var knots:PackedFloat32Array = create_uniform_knots(size, degree, clamped && open)
  var pts:Array[Vector2] = []
  var maxT = 1.0
  if !open:
    maxT = 1.0 - 1.0 / (size - degree)

  pts.resize(steps)
  var r_min:Vector2 = Vector2(INF, INF)
  var r_max:Vector2 = Vector2(-INF, -INF)
  for n in steps:
    var p = interpolate(maxT * n / c, degree, c_points, knots, weights)
    pts[n] = p
    r_min.x = min(r_min.x, p.x)
    r_min.y = min(r_min.y, p.y)
    r_max.x = max(r_max.x, p.x)
    r_max.y = max(r_max.y, p.y)

  if open and min_bottom != 0 and r_max.y < min_bottom:
    # add 2 points at the beginning and end to extend the polygon
    pts.push_front(Vector2(pts[0].x, min_bottom))
    pts.push_back(Vector2(pts[-1].x, min_bottom))
  elif open and min_top != 0 and r_min.y > min_top:
    pts.push_front(Vector2(pts[0].x, min_top))
    pts.push_back(Vector2(pts[-1].x, min_top))

  interpolated_points = PackedVector2Array(pts)
  update_collision_polygon()

  shape_updated.emit()
  queue_redraw()

func _draw() -> void:
  if interpolated_points.is_empty():
    return
  if fill:
    if fill_texture:
      var s = fill_texture.get_size()
      var tx = Transform2D(0, Vector2(1.0 / s.x, 1.0 / s.y), 0, Vector2.ZERO)
      var uvs:PackedVector2Array = tx * interpolated_points
      draw_colored_polygon(interpolated_points, fill_color, uvs, fill_texture)
      texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
    else:
      draw_colored_polygon(interpolated_points, fill_color)

  if border:
    draw_polyline(interpolated_points, border_color, border_width)

static func create_uniform_knots(size:int, degree:int, clamped:bool)->PackedFloat32Array:
  var knots:PackedFloat32Array = PackedFloat32Array()
  var m = size+degree+1
  knots.resize(m)
  var v = 0
  for i in m:
    knots[i] = v
    # A clamped knot vector must have `degree + 1` equal knots at both its beginning and end.
    if !clamped || (i>degree-1 && i < m - degree - 1):
      v += 1
  return knots

static func interpolate(t:float, degree:int, points:PackedVector2Array, knots:PackedFloat32Array, weights:PackedFloat32Array)->Vector2:
  var n:int = points.size();
  assert(degree >= 1, 'degree must be at least 1 (linear)')
  assert(degree < n, 'degree must be less than or equal to point count - 1')
  assert(knots.size() == n+degree+1,'bad knot vector length')

  var domain = [
    degree,
    knots.size()-1 - degree
  ];

  # remap t to the domain where the spline is defined
  var low  = knots[domain[0]];
  var high = knots[domain[1]];
  t = t * (high - low) + low;

  assert (t >= low && t <= high, 'out of bounds')

  # find s (the spline segment) for the [t] value provided
  var s = domain[0]
  while s < domain[1]:
    if t >= knots[s] && t <= knots[s+1]:
      break;
    s += 1


  # convert points to homogeneous coordinates (z is weight)
  var v = PackedVector3Array();
  v.resize(n)
  for i in n:
    var w = weights[i]
    v[i] = Vector3(points[i].x * w, points[i].y * w, w)

  # l (level) goes from 1 to the curve degree + 1
  for l in range(1, degree + 2):
    # build level l of the pyramid
    # (i=s; i>s-degree-1+l; i--) {
    for i in range(s, s-degree-1+l, -1):
      var alpha = (t - knots[i]) / (knots[i+degree+1-l] - knots[i]);
      v[i] = (1 - alpha) * v[i-1] + alpha * v[i];

  # convert back to cartesian and return
  var w = v[s].z;
  return Vector2(v[s].x / w, v[s].y / w)
