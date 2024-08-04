@tool
extends EditorPlugin

enum MODE { CREATE, EDIT, DELETE, CLEAR, PIVOT }

var ctl:Container;
var btn_edit:Button
var btn_create:Button
var btn_delete:Button
var btn_clear:Button
var btn_pivot:Button

var mode:MODE = MODE.EDIT

var spline:Spline2D
var selected_point_idx:int = -1
var create_point_pos:Vector2
var create_point_idx:int = -1
var show_weights:bool = true

const wh_length:float = 100.0

func add_button(tool_tip:String, mode:MODE, icon:String)->Button:
  var btn:Button = Button.new()
  btn.set_theme_type_variation("FlatButton")
  btn.set_toggle_mode(true)
  btn.set_focus_mode(Control.FOCUS_NONE)
  btn.set_tooltip_text(tool_tip)
  btn.connect("pressed", set_mode.bind(mode))
  btn.icon = EditorInterface.get_base_control().get_theme_icon(icon, 'EditorIcons')
  ctl.add_child(btn)
  return btn

func create_container()->Container:
  ctl = HBoxContainer.new()
  btn_edit   = add_button('Select Point\nRight Click: Delete Point"', MODE.EDIT, 'CurveEdit')
  btn_edit.button_pressed = true
  btn_create = add_button("Add Point\nRight Click: Delete Point", MODE.CREATE, 'CurveCreate')
  btn_delete = add_button("Delete Point", MODE.DELETE, 'CurveDelete')
  btn_clear  = add_button("Clear Points", MODE.CLEAR, 'Clear')
  btn_clear.set_toggle_mode(false)
  btn_pivot  = add_button("Set Pivot", MODE.PIVOT, 'EditPivot')
  return ctl;

func set_mode(value:MODE)->void:
  print('Set Mode ', value)
  if value == MODE.CLEAR:
    spline.clear_points()
    update_overlays()
    return
  mode = value
  btn_create.button_pressed = mode == MODE.CREATE
  btn_delete.button_pressed = mode == MODE.DELETE
  btn_edit.button_pressed = mode == MODE.EDIT
  btn_pivot.button_pressed = mode == MODE.PIVOT


func _forward_canvas_gui_input(event:InputEvent)->bool:
  if not event is InputEventMouse:
    return false

  var me = event as InputEventMouse
  var mb = event as InputEventMouseButton
  var mm = event as InputEventMouseMotion
  var et: Transform2D = get_et()
  var t: Transform2D = et * spline.get_global_transform()

  if mb && mb.button_index == MOUSE_BUTTON_LEFT && mb.pressed && mode == MODE.PIVOT:
    var p = t.affine_inverse() * mb.position
    spline.set_pivot(p)
    spline.translate(p)
    update_overlays()
    return true

  var grab_threshold: float = EditorInterface.get_editor_settings().get("editors/polygon_editor/point_grab_radius")

  var handle_idx = -1
  for i in spline.points.size():
    var pt = t * spline.points[i]
    if pt.distance_to(me.position) <= grab_threshold:
      handle_idx = i
      break

  if mb && mb.button_index == MOUSE_BUTTON_RIGHT && handle_idx >=0 && mb.pressed:
    selected_point_idx = -1
    spline.remove_point(handle_idx)
    update_overlays()
    return true

  if mb && mb.button_index == MOUSE_BUTTON_LEFT && mb.pressed:
    if create_point_idx >=0:
      spline.insert_point(create_point_pos, create_point_idx + 1)
      selected_point_idx = create_point_idx + 1
      create_point_idx = -1
      update_overlays()
      return true
    if mode == MODE.CREATE:
      spline.add_point(t.affine_inverse() * mb.position)
      update_overlays()
      return true

    if handle_idx < 0:
      selected_point_idx = -1
      return false
    if mode == MODE.EDIT:
      selected_point_idx = handle_idx
    elif mode == MODE.DELETE:
      selected_point_idx = -1
      spline.remove_point(handle_idx)
    create_point_idx = -1
    update_overlays()
    return true

  if mm && selected_point_idx >=0:
    if mm.button_mask == MOUSE_BUTTON_MASK_LEFT:
      spline.set_point(selected_point_idx, t.affine_inverse() * mm.position)
      update_overlays()
    else:
      selected_point_idx = -1
    return true

  var create_idx = -1
  if mm && (handle_idx < 0) && (mode == MODE.EDIT || mode == MODE.CREATE):
    var info = spline.get_closest_point(t.affine_inverse() * mm.position)
    if info.idx >= 0 && info.d < grab_threshold:
      create_point_pos = info.point
      create_idx = info.idx
  if create_idx >= 0 || create_point_idx >= 0:
    create_point_idx = create_idx
    update_overlays()

  return false

func get_et()->Transform2D:
  return EditorInterface.get_edited_scene_root().get_viewport().global_canvas_transform

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
  if spline.points.is_empty():
    return
  var smoothHandle:Texture2D = overlay.get_theme_icon("EditorPathSmoothHandle", "EditorIcons");
  var handle_size:Vector2 = smoothHandle.get_size()
  var xform:Transform2D = get_et() * spline.get_global_transform()
  var pts:PackedVector2Array = xform * spline.points
  if !spline.open:
    pts.append(pts[0])
  overlay.draw_polyline(pts, Color.RED, 2)
  if !spline.open:
    pts.resize(pts.size() - 1)

  if show_weights:
    var wHandle:Texture2D = overlay.get_theme_icon("EditorCurveHandle", "EditorIcons");
    var wHandle_size:Vector2 = wHandle.get_size()
    if spline.open:
      for i in pts.size():
        var w = spline.weights[i]
        var p = pts[i]
        var n
        if i == 0:
          n = (pts[i + 1] - p).orthogonal().normalized()
        elif i == pts.size() - 1:
          n = (p - pts[i - 1]).orthogonal().normalized()
        else:
          var n0 = (pts[i + 1] - p).orthogonal().normalized()
          var n1 = (p - pts[i - 1]).orthogonal().normalized()
          n = ((n0 + n1) / 2.0).normalized()
        var p1 = p + n * wh_length * w
        overlay.draw_line(p, p1, Color.RED)
        overlay.draw_texture_rect(wHandle, Rect2(p1 - wHandle_size * 0.5, wHandle_size), false)
    else:
      var l = pts.size()
      for i in l:
        var w = spline.weights[i]
        var p = pts[i]
        var n0 = (pts[(i + 1) % l] - p).orthogonal().normalized()
        var n1 = (p - pts[(i + l - 1) % l]).orthogonal().normalized()
        var n:Vector2 = ((n0 + n1) / 2.0).normalized()
        var p1 = p + n * wh_length * w
        overlay.draw_line(p, p1, Color.RED)
        overlay.draw_texture_rect(wHandle, Rect2(p1 - wHandle_size * 0.5, wHandle_size), false)

  for pt:Vector2 in pts:
    overlay.draw_texture_rect(smoothHandle, Rect2(pt -handle_size * 0.5, handle_size), false)
  if create_point_idx >=0:
    var addHandle:Texture2D = overlay.get_theme_icon("EditorHandleAdd", "EditorIcons")
    var ah_size:Vector2 = addHandle.get_size()
    overlay.draw_texture_rect(addHandle, Rect2(xform * create_point_pos -ah_size * 0.5, ah_size), false)



#--------------------------------------------------------------------------------------------------------------------------------

func _enter_tree() -> void:
  add_custom_type("Spline2D", "Node2D", preload("spline_2d.gd"), preload("res://addons/splines/spline_2d.png"))
  create_container()
  add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, ctl)
  ctl.hide()

func _exit_tree() -> void:
  remove_custom_type("Spline2D")
  remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, ctl)
  ctl.queue_free()

func _handles(object: Object) -> bool:
  if object is Spline2D:
    return true
  return false

func _edit(object: Object)->void:
  if object:
    spline = object as Spline2D
    if spline.points.is_empty():
      set_mode(MODE.CREATE)
    spline.shape_updated.connect(_on_shape_updated)
  elif spline:
    spline.shape_updated.disconnect(_on_shape_updated)
    spline = null


func _on_shape_updated()->void:
  update_overlays()

func _make_visible(visible: bool)->void:
  if visible:
    ctl.show()
  else:
    ctl.hide()

