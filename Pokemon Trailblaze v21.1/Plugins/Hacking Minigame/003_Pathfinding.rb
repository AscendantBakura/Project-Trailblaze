class HackingGame_Scene

	# if pbPFCanReach?
	#	path = pbPFShortestPath

	def pbPFCanSeePlayer?(subject, max_steps = nil)
		start = subject.is_a?(Array) ? subject : convert_coords_reverse(subject.x, subject.y)
		player = @sprites["player"]
		max_steps = subject.sight unless subject.is_a?(Array) || max_steps
		return pbPFCanReach?(start, convert_coords_reverse(player.x, player.y), max_steps)
	end

    def pbPFCanReach?(subject, goal, max_steps = nil)
		start = subject.is_a?(Array) ? subject : convert_coords_reverse(subject.x, subject.y)
		came_from, distances = pbPFDistances(start, goal, max_steps)
		return distances && distances[goal]
    end

	def pbPFShortestPath(subject, goal, max_steps = nil)
		start = subject.is_a?(Array) ? subject : convert_coords_reverse(subject.x, subject.y)
		came_from, distances = pbPFDistances(start, goal, max_steps)
		return nil unless distances && distances[goal]

		path = []
		cur = goal
		while cur && cur != start
			path.push(cur)
			cur = came_from[cur]
		end
		path.push(start)
		return path.reverse
	end

    def pbPFDistances(start, goal, max_steps = nil)
		return [nil, nil] unless @nodes[[*start]] && @nodes[[*start]].visible
		return [nil, nil] unless @nodes[[*goal]] && @nodes[[*goal]].visible

		queue = [start]
		queue_index = 0

		checked_nodes = { start => true }
		came_from = {}
		distance = { start => 0 }

		while queue_index < queue.length
			cur = queue[queue_index]
			queue_index += 1

			return came_from, distance if cur == goal

			next if max_steps && distance[cur] >= max_steps

			pbPFVisibleNeighbors(cur).each do |n|
				next if checked_nodes[n]

				checked_nodes[n] = true
				came_from[n] = cur
				distance[n] = distance[cur] + 1
				queue.push(n)
			end
		end

		return came_from, distance
    end

	def pbPFVisibleNeighbors(coords)
		return [] unless @nodes[[*coords]] && @nodes[[*coords]].visible

		x = coords[0]
		y = coords[1]
		neighbors = []

		directions = [[1,0], [-1,0], [0,1], [0,-1]]  # right, left, down, up
		directions.each do |dx, dy|
			neighbor = [x + dx, y + dy]
			next unless @nodes[neighbor] && @nodes[neighbor].visible
			if dx == 0 # Vertical
				if dy < 0 # Above
					if @paths[[*neighbor, *coords]]&.type == :Swap
					end
					next unless @paths[[*neighbor, *coords]] && @paths[[*neighbor, *coords]].can_pass
				else # Below
					next unless @paths[[*coords, *neighbor]] && @paths[[*coords, *neighbor]].can_pass
				end
			else # Horizontal
				if dx < 0 # Left
					next unless @paths[[*neighbor, *coords]] && @paths[[*neighbor, *coords]].can_pass
				else # Right
					next unless @paths[[*coords, *neighbor]] && @paths[[*coords, *neighbor]].can_pass
				end
			end
			neighbors.push(neighbor)
		end

		return neighbors
	end

end