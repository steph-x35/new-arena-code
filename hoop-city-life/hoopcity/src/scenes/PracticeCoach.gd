extends Node2D
## Coach watches practice from beyond the sideline; never part of free play.
func _ready() -> void:
	z_index = 15

func _draw() -> void:
	var p := CourtStage.m_project(Vector2(-700, -365), Court.COURT_H)
	var look := Avatar.colours(false, Color(0.20, 0.22, 0.25))
	look["hair"] = Color(0.88, 0.89, 0.87)
	look["hst"] = 0
	Avatar.draw_body(self, p, 64.0, 1.0, Avatar.pose(Avatar.IDLE, 0.0), look, false)
	# A pale beard under the face, visible even in simplified graphics.
	draw_line(p + Vector2(-6, -48), p + Vector2(6, -48), Color(0.84, 0.84, 0.82), 4.0)
