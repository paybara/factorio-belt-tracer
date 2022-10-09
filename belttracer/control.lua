
local function position_to_string(p)
    return '['..p.x..','..p.y..']'
end

local function is_transport_line(e)
    local belt_types = {'transport-belt', 'splitter', 'underground-belt'}
    for _,belt_type in pairs(belt_types) do
        if e.type == belt_type then
            return true
        end
    end
    return false  
end

local function is_pipe(e)
    local pipe_types = {'pipe', 'pipe-to-ground', 'storage-tank', 'pump', 'offshore-pump', 'generator', 'boiler', 'fluid-turret'}
    for _,pipe_type in pairs(pipe_types) do
        if e.type == pipe_type then
            return true
        end
    end
    return false  
end

local global_prefix = "paybara-belt-tracer-"

local function global_entities(player)
    return global_prefix..player.name.."-entities"
end

local function destroy_all_entities(entities)
    if entities == nil then return end
    for _, e in pairs(entities) do
        e.destroy()
    end
end

local function clear_all(player)
    local p_entities = global_entities(player)
    destroy_all_entities(global[p_entities])
    global[p_entities] = {}
end

local function get_trace_entity(player, s, pos)
    local pos_str = position_to_string(pos)
    e = global[global_entities(player)][pos_str]
    if e == nil then
        e = s.create_entity({
            name = 'paybara-belttracer-trace',
            position = pos,
        })
        global[global_entities(player)][pos_str] = e
    end
    return e
end

-- Draw a line between two entities, on surface s, visible to player.
local function draw_line(from, to, s, player, dashed)
    local dash = 0
    local gap = 0
    if dashed then
        -- Length of dashes and gap between them, in fractions of tiles.
        dash = 0.1
        gap = 0.2
    end
    -- Get or create hidden entities at each end of the line and draw the line attached to them.
    -- That way the trace gets cleaned up if the mod is disabled.
    from = get_trace_entity(player, s, from.position)
    to = get_trace_entity(player, s, to.position)
    local id = rendering.draw_line({
        ["from"]=from,
        ["to"]=to,
        -- TODO: Customize colors.
        ["color"] = {1, 1, 1}, --white
        ["width"] = 1, -- pixels
        ["surface"]=s,  -- Draw on whatever surface the belts are on.
        ["players"]={player}, -- Only draw for the current player
        ["dash_length"]=dash,
        ["gap_length"]=gap
    })
end

-- Draw a small circle on entity e, on surface s, visible to player.
local function draw_circle(e, s, player)
    -- Get or create a hidden entity at this location and draw the circle attached to it.
    -- That way the trace gets cleaned up if the mod is disabled.
    e = get_trace_entity(player, s, e.position)
    local id = rendering.draw_circle({
        ["target"]=e,
        ["radius"]=.3,
        -- TODO: Customize colors.
        ["color"] = {1, 1, 1}, --white
        ["width"] = 1, -- pixels
        ["filled"] = false,
        ["surface"]=s,  -- Draw on whatever surface the belts are on.
        ["players"]={player}, -- Only draw for the current player
    })
end

-- The string key for a table of finished belts or pipes.
local function finishkey(entity)
    return position_to_string(entity.position)
end

local function trace_belt(p, e, verbose)
    local s = e.surface

    -- Leave a circle at the selected tile so you can see where you traced from.
    draw_circle(e, s, p)

    local num_entities = 1
    local num_steps = 1

    -- Trace belts twice: once following inputs, the other following outputs.
    -- (If you trace both directions in a single path, you'll start tracing other outputs of your input,
    -- and other inputs downstream of your output, neither of which are reachable from the selected belt.)
    for _, in_out in pairs({"inputs", "outputs"}) do
        -- Start from the selected entity both times.
        local to_be_walked = {e}
        -- Clear the finished list between passes:
        -- if something is both an input and an output it needs to be traversed both times.
        local finished = {[finishkey(e)]=true}
        local keep_going = true
        while keep_going do
            local next_pass = {}
            local num_next = 0
            keep_going = false
            for _, edge in pairs(to_be_walked) do
                -- Get the belts that are connected to this one as inputs or outputs (depending on which pass we're doing).
                for _, n in pairs(edge.belt_neighbours[in_out]) do
                    -- p.print(in_out.." belt_neighbor "..n.name.." at "..position_to_string(n.position))
                    draw_line(edge, n, s, p, false)
                    if finished[finishkey(n)] == nil then
                        num_next = num_next + 1
                        next_pass[num_next] = n
                        finished[finishkey(n)] = true
                    end
                end
                -- Have to use plain 'neighbors' to get the other end of an underground belt
                --
                -- Trace to the other end of underground belts no matter whether we're following inputs or outputs.
                -- If one end of an underground belt was an input then the other end is too. Same for output.
                if edge.type == 'underground-belt' then
                    local n = edge.neighbours
                    if n ~= nil then
                        -- p.print("neighbor "..n.name.." at "..position_to_string(n.position))
                        if finished[finishkey(n)] == nil then
                            draw_line(edge, n, s, p, true) -- dashed
                            num_next = num_next + 1
                            next_pass[num_next] = n
                            finished[finishkey(n)] = true
                        end
                    end
                end
            end
            if num_next > 0 then
                to_be_walked = next_pass
                keep_going = true
                num_steps = num_steps + 1
                num_entities = num_entities + num_next
                -- p.print("Step "..num_steps.." found "..num_next.." new belts.")
            end
        end
    end
    if verbose then
        p.print("Traced "..num_entities.." belts in "..num_steps.." steps.")
    end
    -- TODO: Play a sound when the trace completes?
end

-- Traces pipes and other entities that hold fluid by walking their 'neighbours'
--
-- TODO: Consider only walking fluid boxes that have a matching locked fluid.
-- For instance, this will avoid jumping between steam and water in boilers.
-- This might let us relax the extra is_pipe check on recursion: if we can save the input fluid box/index,
-- we can look for any other fluid boxes with the same fluid and keep walking them.
-- This should let us expand this to mods that let fluids flow through other entities, like Industrial Revolution.
-- But done naively it might make us jump between systems that are actually disconnected,
-- if they're connected to separate ports on entites that allow multiple inputs/outputs but don't flow between them.
-- I haven't found how the game distinguishes between these, but it does - boilers and steam engines have an icon for bi-di flow,
-- and e.g. chemical plants have icons for only input and only output.
local function trace_pipe(p, e, verbose) 
    local s = e.surface

    local started = false

    local num_entities = 1
    local num_steps = 1

    local to_be_walked = {e}
    local finished = {[finishkey(e)]=true}
    local keep_going = true
    while keep_going do
        local next_pass = {}
        local num_next = 0
        keep_going = false
        for _, e in pairs(to_be_walked) do
            if not started then
                -- Leave a circle at the selected tile so you can see where you traced from.
                -- draw_circle(trace, s, p)
                draw_circle(e, s, p)
                started = true
            end

            -- For belt-connected entities, neighbors is "an array of entity arrays of all entities a given fluidbox is connected to."
            for _, ns in pairs(e.neighbours) do
                for _, n in pairs(ns) do
                    local dashed = false
                    if e.type == "pipe-to-ground" and n.type == "pipe-to-ground" then
                        dashed = true
                    end
                    if not dashed or finished[finishkey(n)] == nil then
                        -- Draw lines even if we've already visited entities to fill in grids of pipes or tanks.
                        -- Just don't double-draw dashed lines, as that can mess them up.
                        -- draw_line(trace, n, s, p, dashed)
                        draw_line(e, n, s, p, dashed)
                    end
                    if finished[finishkey(n)] == nil then
                        -- Pipes can be connected to non-pipes, like assemblers. Draw lines to assemblers but don't recurse into them.
                        if is_pipe(n) then
                            num_next = num_next + 1
                            next_pass[num_next] = n
                            finished[finishkey(n)] = true
                        end
                    end
                end
            end
        end
        if num_next > 0 then
            to_be_walked = next_pass
            keep_going = true
            num_steps = num_steps + 1
            num_entities = num_entities + num_next
        --     p.print("Step "..num_steps.." found "..num_next.." new belts.")
        end
    end
    if verbose then
        p.print("Traced "..num_entities.." pipes in "..num_steps.." steps.")
    end
end


-- This is the main handler function, it runs whenever the trace action is triggered.
script.on_event('paybara:trace-belt', function(event)
    local p = game.players[event.player_index]
    local e = p.selected
    local verbose = settings.get_player_settings(event.player_index)["belttracer-verbose-logging"].value

    if e and verbose then
        for _, over in pairs(e.surface.find_entities_filtered({position = e.position})) do
            p.print("Over entity "..over.name.." of type "..over.type)
        end
    end

    -- Remove any previous trace first, regardless of what you're hovering over.
    clear_all(p)

    if not e then
        -- p.print('not over anything')
        return
    end

    if is_transport_line(e) then
        trace_belt(p, e, verbose)
        return
    end
    if is_pipe(e) then
        trace_pipe(p, e, verbose)
        return
    end
    if verbose then
        p.print('Not over a belt or pipe. name: '..e.name..' type: '..e.type)
    end
end)
