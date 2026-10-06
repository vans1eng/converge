extends RefCounted
class_name AnswerVerifier


static func verify(definition: CellDefinition, runtime: CellRuntimeState) -> Dictionary:
	if definition == null or runtime == null or not definition.is_editable() or runtime.solved:
		return {"ok": false, "reason": "Cell cannot be verified."}

	if definition.mode == CellDefinition.MODE_CANDIDATE:
		if runtime.candidate_pick.is_empty():
			return {"ok": false, "reason": "Choose a candidate color first."}
		var accepted := definition.accepted_answer_types
		return {"ok": runtime.candidate_pick in accepted if not accepted.is_empty() else runtime.candidate_pick == definition.answer_type, "reason": ""}

	if not runtime.player_black and not runtime.pending_black and runtime.player_value == null:
		return {"ok": false, "reason": "Enter a value or mark the cell black first."}
	if definition.is_wildcard():
		return {"ok": not runtime.player_black and not runtime.pending_black, "reason": ""}
	if definition.answer_type == CellDefinition.TYPE_BLACK:
		return {"ok": runtime.player_black or runtime.pending_black, "reason": ""}
	return {
		"ok": not runtime.player_black and not runtime.pending_black and int(runtime.player_value) == int(definition.answer_value),
		"reason": "",
	}
