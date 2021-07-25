extends Node2D

const graph_class = preload("res://graph.gd")

onready var player = $Player
onready var tilemap = $TileMap

enum {bfs, dfs, astar, dijkstra, instant, slow}
var mode = bfs
var speedmode = slow
var ortho = false

var map_graph = preload("res://graph.tscn").instance()
var tile_list
var start_node
var end_node
var running = false

func build_graph():
	map_graph.clear()
	tile_list = tilemap.get_used_cells()
	for tile in tile_list:
		map_graph.add_node(tile)
	for tile in map_graph.graph_dict:
		var top = Vector2(tile.x, tile.y - 1)
		var bottom = Vector2(tile.x, tile.y + 1)
		var left = Vector2(tile.x - 1, tile.y)
		var right = Vector2(tile.x + 1, tile.y)
		if top in tile_list:
			map_graph.add_neighbor(tile, top, 1)
		if bottom in tile_list:
			map_graph.add_neighbor(tile, bottom, 1)
		if left in tile_list:
			map_graph.add_neighbor(tile, left, 1)
		if right in tile_list:
			map_graph.add_neighbor(tile, right, 1)
		if not ortho:
			var top_left = Vector2(tile.x - 1, tile.y - 1)
			var top_right = Vector2(tile.x + 1, tile.y - 1)
			var bottom_left = Vector2(tile.x - 1, tile.y + 1)
			var bottom_right = Vector2(tile.x + 1, tile.y + 1)
			if top_left in tile_list:
				map_graph.add_neighbor(tile, top_left, pow(2, 0.5))
			if top_right in tile_list:
				map_graph.add_neighbor(tile, top_right, pow(2, 0.5))
			if bottom_left in tile_list:
				map_graph.add_neighbor(tile, bottom_left, pow(2, 0.5))
			if bottom_right in tile_list:
				map_graph.add_neighbor(tile, bottom_right, pow(2, 0.5))

func _ready():
	Constants.next_scene = (Constants.next_scene + 1) % len(Constants.worlds)
	build_graph()
	start_node = tilemap.world_to_map(player.global_position)

func _process(delta):
	#First if checks running, do NOT run if running
	if Input.is_action_just_pressed("click") and not running:
		end_node = tilemap.world_to_map(get_global_mouse_position())
		if tilemap.get_cellv(end_node) != -1 and end_node != start_node:
			for line in $Lines.get_children():
				line.queue_free()
			running = true
			if mode == bfs:
				bfs_dfs(start_node, end_node, true)
			elif mode == dfs:
				bfs_dfs(start_node, end_node, false)
			elif mode == astar:
				astar_search(start_node, end_node)
			elif mode == dijkstra:
				dijkstra_search(start_node, end_node)
		
func draw_line_nodes(start, end, color = Color(0.4,0.5,1,1)):
	var line = Line2D.new()
	$Lines.add_child(line)
	line.set_width(3)
	line.set_default_color(color)
	line.add_point(Vector2(start.x * 32 + 16, start.y * 32 + 16))
	line.add_point(Vector2(end.x * 32 + 16, end.y * 32 + 16))
		
func bfs_dfs(start, end, is_bfs):
	var end_reached = false
	#if is_bfs, then use queue, else use stack
	#Queue uses array, so longer runtime
	var visit_data = {}
	var parent_data = {}
	for node in map_graph.graph_dict:
		visit_data[node] = false
	visit_data[start_node] = true
	var rac = [start_node]
	
	var curr_node
	while rac:
		if is_bfs:
			curr_node = rac.pop_front()
		else:
			curr_node = rac.pop_back()
		var neighbors = map_graph.get_neighbors(curr_node)
		neighbors.shuffle()
		for neighbor in neighbors:
			if neighbor == end_node:
				parent_data[neighbor] = curr_node
				draw_line_nodes(curr_node, neighbor)
				rac = []
				curr_node = end_node # for move on path function
				end_reached = true
				break
			elif visit_data[neighbor] == false:
				visit_data[neighbor] = true
				parent_data[neighbor] = curr_node
				rac.append(neighbor)
				draw_line_nodes(curr_node, neighbor)
				if speedmode == slow:
					yield(get_tree(), "idle_frame")
	if not end_reached:
		running = false
		return
	start_node = curr_node
	move_on_path(parent_data, start, curr_node)

func astar_search(start, end):
	#closed/open set will store as following:
	#0: g(c) 1: h(c) 2: curr_parent
	
	var end_reached = false
	var parent_data = {}
	var curr_node = start
	var open_set = {start: [0, start.distance_to(end), null]}
	var closed_set = {}
	
	while open_set:
		var f_cost = {}
		for node in open_set:
			f_cost[node] = open_set[node][0] + open_set[node][1]
		curr_node = null
		for node in f_cost: #assign curr_node the lowest f cost node
			if curr_node == null: # since I can't find a shortcut function
				curr_node = node # to find key with lowest value
			elif f_cost[node] < f_cost[curr_node]:
				curr_node = node
		closed_set[curr_node] = open_set[curr_node]
		var curr_node_g = open_set[curr_node][0]
		open_set.erase(curr_node)
		if curr_node == end:
			end_reached = true
			break
		var curr_nbrs = map_graph.get_neighbors(curr_node)
		for nbr in curr_nbrs:
			var nbr_temp_vals = [curr_node_g + map_graph.graph_dict[curr_node][nbr],
			end.distance_to(nbr), curr_node]
			if not nbr in open_set and not nbr in closed_set:
				open_set[nbr] = nbr_temp_vals
				draw_line_nodes(curr_node, nbr)
				if speedmode == slow:
					yield(get_tree(), "idle_frame")
			elif nbr in open_set and not nbr in closed_set:
				if open_set[nbr][0] + open_set[nbr][1] > \
				nbr_temp_vals[0] + nbr_temp_vals[1]:
					open_set[nbr] = nbr_temp_vals
					draw_line_nodes(curr_node, nbr)
					if speedmode == slow:
						yield(get_tree(), "idle_frame")
	if not end_reached:
		running = false
		return
	for node in closed_set:
		if node != start:
			parent_data[node] = closed_set[node][2]
	start_node = curr_node
	move_on_path(parent_data, start, curr_node)

func dijkstra_search(start, end):
	var end_reached = false
	var parent_data = {}
	var dist = {}
	var unvisited_set = {}
	for node in map_graph.nodes():
		unvisited_set[node] = null
		dist[node] = INF
		if node != start:
			parent_data[node] = null
	dist[start] = 0
	var curr_node = null
	while unvisited_set:
# last_node for unreachable cases, player will just have to go somewhere else
		var last_node = curr_node 
		curr_node = null
		for node in unvisited_set: #get curr_node to be node with min dist.
			if curr_node == null:
				curr_node = node
			elif dist[node] < dist[curr_node]:
				curr_node = node
		if dist[curr_node] == INF:
			curr_node = last_node
			break
		if curr_node == end:
			end_reached = true
			break
		unvisited_set.erase(curr_node)
		for nbr in map_graph.get_neighbors(curr_node):
			if nbr in unvisited_set:
				var temp_dist = dist[curr_node] + map_graph.graph_dict[curr_node][nbr]
				if temp_dist < dist[nbr]:
					dist[nbr] = temp_dist
					parent_data[nbr] = curr_node
					draw_line_nodes(curr_node, nbr)
					if speedmode == slow:
						yield(get_tree(), "idle_frame")
	if not end_reached:
		running = false
		return
	start_node = curr_node
	move_on_path(parent_data, start, curr_node)
		

func move_on_path(parent_dict, start_node, last_node):
	var rcurr_node = last_node
	var path_order = [last_node]
	while rcurr_node in parent_dict:
		path_order.append(parent_dict[rcurr_node])
		rcurr_node = parent_dict[rcurr_node]
	for i in range(len(path_order) - 1, -1, -1):
		var curr = path_order[i]
		player.global_position = Vector2(curr.x * 32 + 16, curr.y * 32 + 16)
		if i != 0: #don't connect start and end nodes! ugly
			draw_line_nodes(path_order[i], path_order[i-1], Color(.5,.8,.5))
		yield(get_tree().create_timer(.05), "timeout")
	running = false


func _on_BFS_pressed():
	mode = bfs
	$ModeLabel.text = "/BFS"	
func _on_DFS_pressed():
	mode = dfs
	$ModeLabel.text = "/DFS"
func _on_Astar_pressed():
	mode = astar
	$ModeLabel.text = "/A*"
func _on_Dijkstra_pressed():
	mode = dijkstra
	$ModeLabel.text = "/Dijkstra"
func _on_SpeedMode_pressed():
	if speedmode == slow:
		speedmode = instant
		$SpeedMode.text = "Instant"
	elif speedmode == instant:
		speedmode = slow
		$SpeedMode.text = "Slow"


func _on_Ortho_pressed():
	if not running:
		ortho = not ortho
		if ortho:
			$Ortho.text = "Ortho."
		else:
			$Ortho.text = "Diag."
		build_graph()


func _on_Next_pressed():
	get_tree().change_scene(Constants.worlds[Constants.next_scene])
