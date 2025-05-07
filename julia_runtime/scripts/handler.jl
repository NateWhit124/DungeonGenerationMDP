using CommonRLInterface
using StaticArrays
using Statistics
using StatsBase
using Compose
using ColorSchemes
using DataStructures
using JSON3
import Cairo, Fontconfig

# Room subtypes are:
	# 1 - OPEN
	# 2 - PILLAR
	# 3 - TRAP
# Enemy subtypes are:
	# 1 - EASY
	# 2 - MEDIUM
	# 3 - HARD
# Chest subtypes are 
	# 1- COMMON
	# 2 - RARE
	# 3 - LEGENDARY
# Agent action types are:
	# 1 - PLACEROOM
	# 2 - PLACEENEMY
	# 3 - PLACECHEST
const NUMSUBTYPES = 3
const WIDTH = 9
const HEIGHT = 9
const MAXENEMIES = 5
const MAXCHESTS = 5

@enum OBJECTTYPES begin
	ROOM
	ENEMY
	CHEST
end

mutable struct DungeonEnv <: AbstractEnv
	width::Int
	height::Int
	agent_position::MVector{2,Int}
	rooms::MMatrix{WIDTH, HEIGHT, Int}
	depth_map::MMatrix{WIDTH, HEIGHT, Int}
	room_entropy::Float64
	enemies::MVector{NUMSUBTYPES,MMatrix{WIDTH, HEIGHT, Int}}
	chests::MVector{NUMSUBTYPES,MMatrix{WIDTH, HEIGHT, Int}}
    num_actions_taken::Int
    max_actions::Int
end

function DungeonEnv(width, height, max_actions)
	agent_position = [Int(ceil(width/2)), Int(ceil(height/2))]

	rooms = MMatrix{width,height}(zeros(Int,width,height))
	rooms[Int(ceil(width/2)), Int(ceil(height/2))] = 1
	depth_map = MMatrix{WIDTH, HEIGHT, Int}(zeros(Int,width,height)) .- 1
	room_entropy = 0

	enemies_temp = []
	for i in 1:NUMSUBTYPES
		push!(enemies_temp, MMatrix{width,height,Int}(zeros(Int, width, height)))
	end
	enemies = SVector{NUMSUBTYPES,MMatrix{width, height, Int}}(enemies_temp)

	chests_temp = []
	for i in 1:NUMSUBTYPES
		push!(chests_temp, MMatrix{width,height,Int}(zeros(Int, width, height)))
	end
	chests = SVector{NUMSUBTYPES,MMatrix{width, height, Int}}(chests_temp)

    num_actions_taken = 0

    return DungeonEnv(width, height, agent_position, rooms, depth_map, room_entropy, enemies, chests, num_actions_taken, max_actions)
end

function CommonRLInterface.observe(env::DungeonEnv)
    room_channels = [
        Float32.(env.rooms .== subtype) for subtype in 1:NUMSUBTYPES
    ]

    enemy_channels = [
        Float32.(env.enemies[i]) ./ MAXENEMIES for i in 1:NUMSUBTYPES
    ]

    chest_channels = [
        Float32.(env.chests[i]) ./ MAXCHESTS for i in 1:NUMSUBTYPES
    ]

    all_channels = vcat(room_channels, enemy_channels, chest_channels)

    # Stack into H×W×C, then permute to W×H×C
    spatial = cat(all_channels...; dims=3)
    spatial = permutedims(spatial, (2, 1, 3))  # now W×H×C
    spatial = reshape(spatial, size(spatial)..., 1)  # add batch dim → W×H×C×1

    # --- Vector input ---
    x, y = env.agent_position
    agent_x = x / env.width
    agent_y = y / env.height

    depth = env.depth_map[x, y]
    depth_norm = depth == -1 ? 0.0f0 : Float32(depth) / (env.width * env.height - 1)

    vec_input = Float32[agent_x, agent_y, depth_norm]

    return spatial, vec_input
end

function CommonRLInterface.reset!(env::DungeonEnv)
    width = env.width
    height = env.height
    agent_position = [Int(ceil(width/2)), Int(ceil(height/2))]

	rooms = MMatrix{width,height}(zeros(Int,width,height))
	rooms[Int(ceil(width/2)), Int(ceil(height/2))] = 1
	depth_map = MMatrix{WIDTH, HEIGHT, Int}(zeros(Int,width,height)) .- 1
	room_entropy = 0

	enemies_temp = []
	for i in 1:NUMSUBTYPES
		push!(enemies_temp, MMatrix{width,height,Int}(zeros(Int, width, height)))
	end
	enemies = SVector{NUMSUBTYPES,MMatrix{width, height, Int}}(enemies_temp)

	chests_temp = []
	for i in 1:NUMSUBTYPES
		push!(chests_temp, MMatrix{width,height,Int}(zeros(Int, width, height)))
	end
	chests = SVector{NUMSUBTYPES,MMatrix{width, height, Int}}(chests_temp)

    env.agent_position = agent_position
    env.rooms = rooms
    env.depth_map = depth_map
    env.room_entropy = room_entropy
    env.enemies = enemies
    env.chests = chests
    env.num_actions_taken = 0
end

function CommonRLInterface.actions(env::DungeonEnv)
	# Actions are move up, down, left, right, place room, or place object in a room
	# Objects that can be placed are each subtype of enemy or chest
	# This results in 4 (directions) + (number of object types)*(number of object subtypes) (place an object) actions
	return 1:(4 + length(instances(OBJECTTYPES))*NUMSUBTYPES)
end

action_to_move_vector = Dict(
	1 => SVector{2,Int}([0,-1]),
	2 => SVector{2,Int}([0,1]),
	3 => SVector{2,Int}([-1,0]),
	4 => SVector{2,Int}([1,0])
)

"""
Utility function to retrieve the enum type and subtype index for what object the action is placing\n
WARNING: not safe for actions that are not object placement ( a <= 4 ) to avoid redundant checks
Returns: object_type, object_subtype
"""
function get_object_from_action(a)	
	return OBJECTTYPES( Int(floor((a - 5) / (NUMSUBTYPES))) ), ((a-5) % NUMSUBTYPES) + 1
end

function CommonRLInterface.terminated(env::DungeonEnv)
	return env.num_actions_taken >= env.max_actions
end

function CommonRLInterface.act!(env::DungeonEnv, a)
    if env.num_actions_taken >= env.max_actions
        return 0
    end

    env.num_actions_taken += 1
	if a <= 4 # if the action is not a move action
		env.agent_position += action_to_move_vector[a]
	else
		object_type_to_place, object_subtype_to_place = get_object_from_action(a)
		if object_type_to_place == ROOM
			env.rooms[env.agent_position...] = object_subtype_to_place
			env.depth_map = calculate_room_depths(env)
		elseif object_type_to_place == ENEMY
			env.enemies[object_subtype_to_place][env.agent_position...] += 1
		elseif object_type_to_place == CHEST
			env.chests[object_subtype_to_place][env.agent_position...] += 1
		end
	end

    # assigning rewards
    reward = 0
    x, y = env.agent_position
    depth = env.depth_map[x, y]
    
    if a <= 4
        reward -= 50
    end
    
    if a > 4
        object_type_to_place, object_subtype_to_place = get_object_from_action(a)
    
        if object_type_to_place == ROOM
            reward += 5
            placed_rooms = filter(!=(0), env.rooms)
            room_types_count = countmap(placed_rooms)
            room_count_values = collect(values(room_types_count))
            p = room_count_values / sum(room_count_values)
            room_entropy = entropy(p)
            if room_entropy > env.room_entropy
                reward += 10
            end
            env.room_entropy = room_entropy
    
        elseif object_type_to_place == ENEMY
            # Encourage placing stronger enemies deeper
            base_reward = object_subtype_to_place * (depth + 1)
            penalty = object_subtype_to_place * max(0, 5 - depth)  # penalize early difficulty
            reward += base_reward - penalty
    
        elseif object_type_to_place == CHEST
            # Encourage better items deeper
            base_reward = object_subtype_to_place * (depth + 1) * 0.5
            penalty = object_subtype_to_place * max(0, 5 - depth) * 0.5  # penalize early power-ups
            reward += base_reward - penalty
        end
    
        # Check balance between difficulty and strength at current location
        total_enemy_difficulty = sum(
            subtype * env.enemies[subtype][x, y] for subtype in 1:NUMSUBTYPES
        )
        total_chest_value = sum(
            subtype * env.chests[subtype][x, y] for subtype in 1:NUMSUBTYPES
        )
    
        # If the room has both: try to balance
        if total_enemy_difficulty + total_chest_value > 0
            mismatch = abs(total_enemy_difficulty - total_chest_value)
            reward += max(0, 5 - mismatch)  # reward balance
        end
    end
    
    return reward
end

function CommonRLInterface.valid_actions(env::DungeonEnv)
	valid = []
    if terminated(env)
        return valid
    end

	for a in actions(env)

		# If this is a move action and the agent is on a tile with no room,
		# 	the agent can only move to an adjacently placed room (not diagonal)
		# This prevents the agent from creating disjointed dungeons
		# The agent is free to move any direction if they are currently on a placed room
		if a <= 4 # if this is a move action
			dir = action_to_move_vector[a]
			next_pos = env.agent_position + dir

			# this action is not valid if it puts us out of bounds of the grid map
			if next_pos[1] < 1 || next_pos[1] > env.width || next_pos[2] < 1 || next_pos[2] > env.height
				continue
			end
			
			# if the agent is on a tile with no room placed, it can only move to a tile with a room
			if env.rooms[env.agent_position...] == 0
				if next_pos[1] > 0 && next_pos[1] <= env.width && next_pos[2] > 0 && next_pos[2] <= env.height && env.rooms[next_pos...] != 0
					push!(valid, a)
				end
			# if the agent is on a tile with a room, it is free to move any direction
			else
				push!(valid, a)
			end
		
		elseif a > 4 # if this is an object placement action
			object_type_to_place, object_subtype_to_place = get_object_from_action(a)
			if object_type_to_place == ROOM
				# the agent can only place rooms on tiles without a room already placed on it
				if env.rooms[env.agent_position...] == 0
					push!(valid,a)
				end
            # if we are placing any object that is not a room
            # the agent can only place "non-room" objects on tiles with a room already placed
            # cannot place more than MAXENEMIES and MAXCHESTS
			else
                if env.rooms[env.agent_position...] != 0
                    if object_type_to_place == ENEMY && env.enemies[object_subtype_to_place][env.agent_position...] < MAXENEMIES
                        push!(valid, a)
                    elseif object_type_to_place == CHEST && env.chests[object_subtype_to_place][env.agent_position...] < MAXCHESTS
                        push!(valid, a)
                    end
				end
			end
		end

	end
	return valid
end

"""
Calculates the depth of each room from the starting room.
Should be recalculated every time a room is placed. 
"""
function calculate_room_depths(env::DungeonEnv)
    start = Tuple{Int, Int}( [Int(ceil(env.width/2)), Int(ceil(env.height/2))] )
    depths = MMatrix{WIDTH, HEIGHT, Int}(zeros(Int,env.width,env.height)) .- 1
    depths[start...] = 0
    q = Queue{Tuple{Int,Int}}()
    enqueue!(q, start)

    while !isempty(q)
        u = dequeue!(q)
        d = depths[u...]
        for (dx,dy) in ((1,0),(-1,0),(0,1),(0,-1))
            v = (u[1]+dx, u[2]+dy)
            if 0 < v[1] <= env.width && 0 < v[2] <= env.height && env.rooms[v...] != 0 && depths[v...] == -1
                depths[v...] = d + 1
                enqueue!(q, v)
            end
        end
    end

    return depths
end

"ASCII rendering of rooms"
function render_ascii(env::DungeonEnv)
	println("\n####### ROOMS #######")
    for y in env.height:-1:1  # print top-down
        for x in 1:env.width
            env.rooms[x,y] == 0 ? print(".") : print(string(env.depth_map[x, y]))
        end
        println()
    end
end

"Produces a PNG representation of the placed rooms"
function render_compose(env::DungeonEnv)
    nx, ny = env.width, env.height
    ROOM_COLORS  = Dict(0=>"white", 1=>"lightblue", 2=>"gold", 3=>"salmon")

    # tile forms...
    tiles = [
      compose(
        context((x-1)/nx, (ny-y)/ny, 1/nx, 1/ny),
        rectangle(), fill(ROOM_COLORS[env.rooms[x,y]]), stroke("black")
      ) for x in 1:nx, y in 1:ny
    ]
    grid = compose(context(), linewidth(0.5mm), tiles...)

    # agent...
    ax, ay = env.agent_position
    agent = compose(
      context((ax-1)/nx, (ny-ay)/ny, 1/nx, 1/ny),
      circle(0.5,0.5,0.4), fill("orange"), stroke("black")
    )

    outline = compose(context(), rectangle(), stroke("gray"), linewidth(1mm))

    return compose(context(), agent, grid, outline)
end
function CommonRLInterface.render(env::DungeonEnv; w=600, h=600)
    fig = render_compose(env)
    draw(PNG("dungeon.png", w, h), fig)
    nothing
end

"Used to test interfacing with Godot"
function create_random_dungeon()
    num_actions = 100
	env = DungeonEnv(WIDTH,HEIGHT,num_actions)

	for _ in 1:100
        if terminated(env)
            break
        else
		    act!(env, rand(valid_actions(env)))
        end
	end

	json_str = create_state_json(env)
	println(json_str)
    render(env)
end

"Creates the JSON that is sent to Godot for creating the game map"
function create_state_json(env::DungeonEnv)
	state = Dict(
	"width"   => env.width,
	"height"  => env.height,
	"rooms"   => Array(env.rooms),
	"enemies" => [Array(mat) for mat in env.enemies],
	"chests"  => [Array(mat) for mat in env.chests]
	)
	json_str = JSON3.write(state)
	return json_str
end

#####################################
#--------------- DQN ---------------#
#####################################
# using Flux
# using Flux: throttle, flatten, mse, gradient
# using Statistics
# using Random
# using CommonRLInterface
# using Plots
# using Flux, JLD2, FileIO

# # The model architecture is as follows:
# # One convolutional model and one MLP model that fuse outputs into a final MLP
# # The convoultional model takes all state maps (rooms, enemies, and chests maps),
# #   where each of these maps encodes what subtype/amount of object is placed in the first channel,
# #   and the second channel specifies the depth of each room from the starting room
# const NUM_CHANNELS = 3*NUMSUBTYPES # 3subtypes*(rooms + enemies + chests)
# const NUM_ACTIONS = 4 + length(instances(OBJECTTYPES))*NUMSUBTYPES
# const GAMMA = 0.99f0
# const EPS_START = 1.0f0
# const EPS_END   = 0.5f0
# const EPS_DECAY = 500
# const NUM_EPOCHS = 999
# const BATCH_SIZE = 5
# const REPLAY_CAPACITY = 200
# const TARGET_SYNC_INTERVAL = 20
# const LR = 1e-2

# # Experience replay buffer
# mutable struct ReplayBuffer
#     s::Vector{Any}
#     a_idx::Vector{Int}
#     r::Vector{Float32}
#     sp::Vector{Any}
#     done::Vector{Bool}
#     pos::Int
#     full::Bool
# end

# function ReplayBuffer(cap)
#     ReplayBuffer(
#         Vector{Any}(undef, cap),
#         Vector{Int}(undef, cap),
#         Vector{Float32}(undef, cap),
#         Vector{Any}(undef, cap),
#         Vector{Bool}(undef, cap),
#         1, false
#     )
# end

# function push_replay!(buf::ReplayBuffer, s, a_idx, r, sp, done)
#     buf.s[buf.pos] = s
#     buf.a_idx[buf.pos] = a_idx
#     buf.r[buf.pos] = r
#     buf.sp[buf.pos] = sp
#     buf.done[buf.pos] = done
#     buf.pos = (buf.pos % length(buf.s)) + 1
#     buf.full = buf.full || (buf.pos == 1)
# end

# function sample(buf::ReplayBuffer, n)
#     maxidx = buf.full ? length(buf.s) : buf.pos - 1
#     idx = rand(1:maxidx, n)
#     return buf.s[idx], buf.a_idx[idx], buf.r[idx], buf.sp[idx], buf.done[idx]
# end

# function select_action(conv_model, mlp_model, fusion_model, env, s, epoch_n)
#     epsilon = EPS_START * (1 - epoch_n / EPS_DECAY) + EPS_END
#     maps, vec3 = s

#     all_acts = actions(env)
#     valid_acts = valid_actions(env)
#     q_vals = vec(agent_model(conv_model, mlp_model, fusion_model, maps, vec3))

#     if rand() < epsilon
#         # Exploration: choose valid action at random
#         a = rand(valid_acts)
#         idx = findfirst(==(a), all_acts)
#         return idx === nothing ? 1 : idx  # Fallback to safe default
#     else
#         # Exploitation: mask out invalid actions
#         masked_q_vals = fill(-Inf32, length(q_vals))
#         for (i, a) in enumerate(all_acts)
#             if a in valid_acts
#                 masked_q_vals[i] = q_vals[i]
#             end
#         end
#         return argmax(masked_q_vals)
#     end
# end

# function agent_model(conv_model, mlp_model, fusion_model, maps, vec3)
#     h_map = conv_model(maps)
#     h_vec = mlp_model(vec3)
#     return vcat(h_map, h_vec) |> fusion_model
# end   

# function loss(conv_model, mlp_model, fusion_model, target_conv, target_mlp, target_fusion, batch, env, valid_acts)
#     total_loss = 0.0f0
#     s_batch, a_inds, rs, sp_batch, dones = batch

#     s_maps  = [s[1] for s in s_batch]
#     s_vecs  = [s[2] for s in s_batch]
#     sp_maps = [sp[1] for sp in sp_batch]
#     sp_vecs = [sp[2] for sp in sp_batch]

#     for idx in 1:length(s_batch)
#         s_map, s_vec = s_maps[idx], s_vecs[idx]
#         a_ind = a_inds[idx]
#         r = rs[idx]
#         sp_map, sp_vec = sp_maps[idx], sp_vecs[idx]
#         done = dones[idx]

#         if !(actions(env)[a_ind] in valid_acts)
#             continue
#         end

#         q_vals_sp = agent_model(target_conv, target_mlp, target_fusion, sp_map, sp_vec)
#         ap_ind = argmax(q_vals_sp)
#         target = r
#         if !done
#             target += GAMMA * q_vals_sp[ap_ind]
#         end
#         pred = agent_model(conv_model, mlp_model, fusion_model, s_map, s_vec)[a_ind]
#         total_loss += (target - pred)^2
#     end

#     return total_loss / length(s_batch)
# end

# function dqn(env, num_epochs)
#     conv_model = Chain(
#         Conv((3, 3), NUM_CHANNELS => 32, relu),
#         Conv((3, 3), 32 => 64, relu),
#         flatten
#     )
#     mlp_model = Chain(
#         Dense(3, 32, relu),
#         Dense(32, 32, relu)
#     )
#     fusion_model = Chain(
#         Dense(1600 + 32, 256, relu),
#         Dense(256, 128, relu),
#         Dense(128, 4 + length(instances(OBJECTTYPES))*NUMSUBTYPES) # output: Q values for each action
#     ) 

#     target_conv = deepcopy(conv_model)
#     target_mlp  = deepcopy(mlp_model)
#     target_fusion = deepcopy(fusion_model)
#     function agent_model_target(conv_model, mlp_model, fusion_model, maps, vec3)
#         h_map = conv_model(maps)
#         h_vec = mlp_model(vec3)
#         return vcat(h_map, h_vec) |> fusion_model
#     end

#     opt = ADAM(LR)
#     ps = Flux.trainable((conv_model, mlp_model, fusion_model))
#     opt_state = Flux.setup(opt, ps)

#     buf = ReplayBuffer(REPLAY_CAPACITY)
#     losses = []

#     best_loss = Inf
#     best_conv = deepcopy(conv_model)
#     best_mlp = deepcopy(mlp_model)
#     best_fusion = deepcopy(fusion_model)

#     for epoch in 1:num_epochs
#         @show epoch
#         if epoch % TARGET_SYNC_INTERVAL == 0
#             target_conv = deepcopy(best_conv)
#             target_mlp  = deepcopy(best_mlp)
#             target_fusion = deepcopy(best_fusion)
#             agent_model_target = (maps, vec3) -> begin
#                 h_map = target_conv(maps)
#                 h_vec = target_mlp(vec3)
#                 return vcat(h_map, h_vec) |> target_fusion
#             end
#         end
        

#         s = CommonRLInterface.observe(env)
#         a_idx = select_action(conv_model, mlp_model, fusion_model, env, s, epoch)
#         @show actions(env)[a_idx]
#         @assert actions(env)[a_idx] in valid_actions(env) "Selected invalid action!"
#         r = act!(env, actions(env)[a_idx])
#         sp = CommonRLInterface.observe(env)
#         done = terminated(env)
#         push_replay!(buf, s, a_idx, r, sp, done)

#         # select some data from the buffer and train (you may have to adjust some things, and you will have to do this many times):
#         batch = sample(buf, BATCH_SIZE)
#         valid_acts = valid_actions(env)
#         loss_fn = (ps) -> loss(conv_model, mlp_model, fusion_model, target_conv, target_mlp, target_fusion, batch, env, valid_acts)
#         loss_value, grads = Flux.withgradient(loss_fn, ps)
#         push!(losses,loss_value)
#         Flux.update!(opt_state, ps, grads)

#         if loss_value < best_loss
#             best_loss = loss_value
#             best_conv = deepcopy(conv_model)
#             best_mlp = deepcopy(mlp_model)
#             best_fusion = deepcopy(fusion_model)
#         end        
#         # loss_value, grads = Flux.withgradient(() -> loss(agent_model, agent_model_target, batch, env), ps)
#         # Flux.update!(opt, ps, grads)
        
#         if CommonRLInterface.terminated(env)
#             CommonRLInterface.reset!(env)
#         end
#     end

#     return agent_model, losses
# end

# function create_dungeon(Q, env)
#     while !terminated(env)
#         s = CommonRLInterface.observe(env)
#         maps, vec3 = s

#         all_acts = actions(env)
#         valid_acts = valid_actions(env)
#         q_vals = vec(Q(maps, vec3))

#         # Mask invalid actions
#         masked_q_vals = fill(-Inf32, length(q_vals))
#         for (i, a) in enumerate(all_acts)
#             if a in valid_acts
#                 masked_q_vals[i] = q_vals[i]
#             end
#         end

#         a_idx = argmax(masked_q_vals)
#         a = all_acts[a_idx]

#         act!(env, a)
#     end
# end

max_actions = 500
env = DungeonEnv(WIDTH, HEIGHT, max_actions)
# @load "best_dqn_model.jld2" Q
# create_random_dungeon(Q, env)
# render(env)
nothing