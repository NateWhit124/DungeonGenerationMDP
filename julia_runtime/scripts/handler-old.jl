using CommonRLInterface
using StaticArrays
using Statistics
using StatsBase

const num_subtypes = 3
@enum ROOMTYPES begin
	NOROOM
	OPEN
	PILLAR
	TRAP
end

@enum ENEMYTYPES begin
	NOENEMY
	EASY
	MEDIUM
	HARD
end

@enum TREASURETYPES begin
	NOTREASURE
	COMMON
	RARE
	LEGENDARY
end

@enum ACTIONTYPES begin
	PLACEROOM
	PLACEENEMY
	PLACECHEST
end


mutable struct DungeonEnv <: AbstractEnv
	width::Int
	height::Int
	rooms::MMatrix{10, 10, Int}
	room_entropy::Float64
	enemies::MVector{num_subtypes,SMatrix{10, 10, Int}}
	chests::MVector{num_subtypes,SMatrix{10, 10, Int}}
end

function DungeonEnv(width, height)
	rooms = MMatrix{width,height}(zeros(Int8,width,height))
	rooms[Int(width/2), Int(height/2)] = 1
	
	room_entropy = 0

	enemies_temp = []
	for i in 1:num_subtypes
		push!(enemies_temp, SMatrix{width,height,Int}(zeros(Int, width, height)))
	end
	enemies = SVector{num_subtypes,SMatrix{width, height, Int}}(enemies_temp)

	chests_temp = []
	for i in 1:num_subtypes
		push!(chests_temp, SMatrix{width,height,Int}(zeros(Int, width, height)))
	end
	chests = SVector{num_subtypes,SMatrix{width, height, Int}}(chests_temp)

    return DungeonEnv(width,height,rooms,room_entropy,enemies,chests)
end

function CommonRLInterface.reset!(env::DungeonEnv)
	fill!(env.rooms,NOROOM)
	fill!(env.enemies,NOENEMY)
	fill!(env.chests,NOCHEST)
end

function CommonRLInterface.actions(env::DungeonEnv)
	acts = SVector{4, Int}[]
	for x in 1:env.width
		for y in 1:env.height
			for action_type in 0 : (sizeof(ACTIONTYPES) - 1)
				for action_subtype in 1 : num_subtypes
					push!(acts, SVector{4,Int}([x,y,action_type,action_subtype]))
				end
			end
		end
	end
    return SVector{env.width*env.height*sizeof(ACTIONTYPES)*(num_subtypes), SVector{4, Int}}(acts)
end

function CommonRLInterface.observe(env::DungeonEnv)
	return env.rooms, env.enemies, env.chests
end

function CommonRLInterface.terminated(env::DungeonEnv)
	return false
end

function CommonRLInterface.act!(env::DungeonEnv, a)
	action_x = a[1]
	action_y = a[2]
	action_type = a[3]
	action_subtype = a[4]
	if action_type == 0
		env.rooms[action_x, action_y] = action_subtype
	elseif action_type == 1
		env.rooms[action_x, action_y] = action_subtype
	elseif action_type == 2
		env.rooms[action_x, action_y] = action_subtype
	end

	reward = 0
	env.room_entropy
	placed_rooms = filter(!=(0), env.rooms)
	room_types_count = countmap(placed_rooms)
	room_count_values = collect(values(room_types_count))
	p = room_count_values / sum(room_count_values)
	room_entropy = entropy(p)
	if room_entropy > env.room_entropy
		reward += 10
	end
	env.room_entropy = room_entropy 

    return reward
end

function is_room_adjacent(env::DungeonEnv, x, y)
	for offset in [[-1,0],[1,0],[0,-1],[0,1]]
		x_check = x + offset[1]
		y_check = y + offset[2]
		if x_check < env.width && x_check > 0 && y_check < env.height && y_check > 0
			if env.rooms[x_check, y_check] != Int(NOROOM) 
				return true
			end
		end
	end
	return false
end

function CommonRLInterface.valid_actions(env::DungeonEnv)
	valid = []
	for a in actions(env)
		x, y, type = a[1], a[2], a[3]
		if type == Int(PLACEROOM) && env.rooms[x,y] == Int(NOROOM) && is_room_adjacent(env, x, y)
			push!(valid,a)
		elseif type != Int(PLACEROOM) && env.rooms[x,y] != Int(NOROOM)
			push!(valid,a)
		end
	end
	return valid
end

# CommonRLInterface.observations(env::GridWorldEnv) = [SA[x, y] for x in 1:env.size[1], y in 1:env.size[2]]
# CommonRLInterface.clone(env::GridWorldEnv) = GridWorldEnv(env.size, copy(env.rewards), env.state)
# CommonRLInterface.state(env::GridWorldEnv) = env.state
# CommonRLInterface.setstate!(env::GridWorldEnv, s) = (env.state = s)

function render_ascii(env::DungeonEnv)
    symbols = Dict(
        0 => '.',  # No room
        1 => 'N',  # Room type 1
        2 => 'P',  # Room type 2 (e.g., fire)
        3 => 'T'   # Room type 3 (e.g., shop)
    )

    for y in env.height:-1:1  # print top-down
        for x in 1:env.width
            print(symbols[env.rooms[x, y]])
        end
        println()
    end
end


env = DungeonEnv(10,10)
for x in 1:10
	for y in 1:10
		if rand() < 0.1
			act!(env, rand(valid_actions(env)))
		end
	end
end
@show env.rooms
@show valid_actions(env)
@show length(valid_actions(env))
@show length(actions(env))

render_ascii(env)

mutable struct QLearning{w, h}
    S::SVector{3,SMatrix{w, h, Int}} # 3 x width x height grid representing the location of rooms, enemies, and chests, respectively
    A::SVector{3,Int} # first int represents what we are placing, last 2 ints represent the coordinates of the placement
    gamma::Float64
    Q::Dict{Tuple{SVector{3, SMatrix{w,h}}, SVector{3,Int}}, Float64}
    alpha::Float64
end

function update!(model::QLearning, s, a, r, sp)
    gamma, Q, alpha = model.gamma, model.Q, model.alpha
    Q[s,a] = get(Q,(s,a),0.0) + alpha*(r + gamma*maximum(get(Q, (sp, a2), 0.0) for a2 in model.A) - get(Q,(s,a),0.0))
    return model
end

function simulate!(gw, model::QLearning, π, policy, r_total, h)
    s = observe(gw)
    for i in 1:h
        if terminated(gw)
            a = π(model, s)
            policy[s] = a
            r = act!(gw,a)
            r_total += r
            break
        else
            a = π(model, s)
            policy[s] = a
            r = act!(gw, a)
            r_total += r
            sp = observe(gw)
            update!(model, s, a, r, sp)
            s = sp
        end
    end
    reset!(gw)
    return r_total
end

function π_explore(model::QLearning, s)
    ϵ = 0.05
    if rand() < ϵ
        return rand(model.A)
    else
        maxQ = 0
        maxA = nothing
        for a in model.A
            if haskey(model.Q,(s,a)) && model.Q[s,a] > maxQ
                maxQ = model.Q[s,a]
                maxA = a
            end
        end
        if maxA != nothing
            return maxA
        else
            return rand(model.A)
        end
    end
end

function π_learned(model::QLearning, s)
    maxQ = 0
    maxA = nothing
    for a in model.A
        if haskey(model.Q,(s,a)) && model.Q[s,a] > maxQ
            maxQ = model.Q[s,a]
            maxA = a
        end
    end
    if maxA != nothing
        return maxA
    else
        return rand(model.A)
    end
end

function get_U(model::QLearning, s)
    max_value = -Inf
    for a in model.A
        if haskey(model.Q, (s, a))
            max_value = max(max_value, model.Q[(s, a)])
        end
    end
    return max_value
end

# model = QLearning(
#     observe(gw), # S
#     actions(gw), # A
#     1, # gamma
#     Dict{Tuple{SVector{2,Int}, SVector{2,Int}}, Float64}(), # Q
#     0.5 # alpha
# )
# policy = Dict{SVector{2,Int},SVector{2,Int}}()
# for i in 1:100000
#     r_total = 0
#     r_total = simulate!(gw,model,π_explore,policy,r_total,1000)
# end

# U = Dict{SVector{2,Int}, Float64}()
# for ((s,a),reward) in model.Q
#     U[s] = get_U(model,s)
# end

# policy = Dict{SVector{2,Int},SVector{2,Int}}()
# r_totals = Vector{Float64}()
# for i in 1:5000
#     r_total = 0
#     r_total = simulate!(gw,model,π_learned,policy,r_total,1000)
#     append!(r_totals,r_total)
# end