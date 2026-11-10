extends RefCounted
## Builds a support graph from block rectangles.
## Edges point from a grounded/supporting block to the block resting on it.

static func find_unsupported(blocks: Array, team: String, floor_y: float) -> Array[int]:
	var adjacency: Dictionary = {}
	var grounded: Array[int] = []

	for i in range(blocks.size()):
		var block: Dictionary = blocks[i]
		if block.get("team", "") != team:
			continue
		var rect: Rect2 = block["rect"]
		if rect.position.y >= floor_y - 28.0:
			grounded.append(i)
		adjacency[i] = []

	for upper_index in range(blocks.size()):
		var upper: Dictionary = blocks[upper_index]
		if upper.get("team", "") != team:
			continue
		var upper_rect: Rect2 = upper["rect"]
		for lower_index in range(blocks.size()):
			if upper_index == lower_index:
				continue
			var lower: Dictionary = blocks[lower_index]
			if lower.get("team", "") != team:
				continue
			var lower_rect: Rect2 = lower["rect"]
			var vertical_gap: float = absf(lower_rect.position.y - upper_rect.end.y)
			var horizontal_overlap: float = minf(upper_rect.end.x, lower_rect.end.x) - maxf(upper_rect.position.x, lower_rect.position.x)
			var required_overlap: float = minf(8.0, upper_rect.size.x * 0.3)
			if vertical_gap <= 12.0 and horizontal_overlap >= required_overlap:
				adjacency[lower_index].append(upper_index)

	var visited: Dictionary = {}
	var queue: Array[int] = grounded.duplicate()
	var cursor := 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		if visited.has(current):
			continue
		visited[current] = true
		for supported_index in adjacency.get(current, []):
			if not visited.has(supported_index):
				queue.append(supported_index)

	var unsupported: Array[int] = []
	for i in range(blocks.size()):
		var block: Dictionary = blocks[i]
		if block.get("team", "") == team and not visited.has(i):
			var rect: Rect2 = block["rect"]
			if rect.position.y < floor_y - 28.0:
				unsupported.append(i)
	return unsupported
