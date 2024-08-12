extends Node
class_name XXHash

var seed:int

func _init(seed:int = 0)->void:
  self.seed = seed if seed > 0 else randi()

func hash(x:int, y:int)->float:
  var h:int = seed + x * 374761393 + y * 668265263 # all constants are prime
  h = (h ^ (h >> 13)) * 1274126177;
  h ^= (h >> 16);
  return (h & 0x00ffffff) * (1.0 / 0x1000000);
