@tool
extends Node2D
class_name Spline2D

signal shape_updated()

## Control Points
@export var points:PackedVector2Array = PackedVector2Array()

## Weights
@export var weights:PackedFloat32Array = PackedFloat32Array()

## cached interpolated points
var interpolated_points:PackedVector2Array

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

# -------------------------------------------------------------------------

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

func remove_point(idx:int)->void:
  points.remove_at(idx)
  weights.remove_at(idx)
  print_debug('removed point at %d (size=%d)' % [idx, points.size()])
  update_shape()

func clear_points()->void:
  points.clear()
  weights.clear()
  interpolated_points.clear()
  print_debug('clear points')
  queue_redraw()

func reset_weights()->void:
  weights.fill(1)
  print_debug('reset weights')
  update_shape()

func set_pivot(p:Vector2)->void:
  for i in points.size():
    points[i] -= p
  print_debug('set pivot')
  update_shape()

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

func update_shape():
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
  var pts:PackedVector2Array = PackedVector2Array()
  var maxT = 1.0
  if !open:
    maxT = 1.0 - 1.0 / (size - degree)

  pts.resize(steps)
  for n in steps:
    pts[n] = interpolate(maxT * n / c, degree, c_points, knots, weights)
  interpolated_points = pts
  shape_updated.emit()
  queue_redraw()

func _draw() -> void:
  if interpolated_points.is_empty():
    return
  if fill:
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
