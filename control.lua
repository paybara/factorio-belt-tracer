
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

local global_prefix = "paybara-belt-tracer-"
local function global_ids(p) 
    return global_prefix..p.name"-ids"
end

-- Draw a line between two entities, on surface s, visible to player p.
local function draw_line(from, to, s, p, dashed)
    local dash = 0
    local gap = 0
    if dashed then
        -- Length of dashes and gap between them, in fractions of tiles.
        dash = 0.1
        gap = 0.2
    end
    local id = rendering.draw_line({
        ["from"]=from,
        ["to"]=to,
        -- TODO: Customize colors.
        ["color"] = {1, 1, 1}, --white
        ["width"] = 1, -- pixels
        ["surface"]=s,  -- Draw on whatever surface the belts are on.
        ["players"]={p}, -- Only draw for the current player
        ["dash_length"]=dash,
        ["gap_length"]=gap
    })
    -- Save the ID in the global table so it can be cleaned up later.
    global[global_ids(p)][id] = true
    -- TODO: Figure out how to associate the lines with this mod, so they're removed at load time
    -- if the mod is removed. I might need my own hidden entities associated with each line, rather than
    -- attaching them directly to the entities on the map? I should check what bottleneck does...
end

-- This is the main handler function, it runs whenever the trace action is triggered.
script.on_event('paybara:trace-belt', function(event)
    local p = game.players[event.player_index]

    -- Remove any previous trace first, regardless of what you're hovering over.
    if global[(global_ids(p))] ~= nil then
        for id, _ in pairs(global[global_ids(p)]) do
            rendering.destroy(id)
        end
    end
    global[global_ids(p)] = {}

    local e = p.selected
    if not e then
        -- p.print('not over anything')
        return
    end
    if not is_transport_line(e) then
        -- p.print('not a belt. name: '..e.name..' type: '..e.type)
        return
    end

    local s = e.surface

    -- Leave a circle at the selected tile so you can see where you traced from.
    local id = rendering.draw_circle({
        ["target"]=e,
        ["radius"]=.3,
        -- TODO: Customize colors.
        ["color"] = {1, 1, 1}, --white
        ["width"] = 1, -- pixels
        ["filled"] = false,
        ["surface"]=s,  -- Draw on whatever surface the belts are on.
        ["players"]={p}, -- Only draw for the current player
    })
    -- Save the ID in the global table so it can be cleaned up later.
    global[global_ids(p)][id] = true
 
    -- The string key for the table of finished belts.
    local function finishkey(entity)
        return position_to_string(entity.position)
    end

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
            for _, e in pairs(to_be_walked) do
                -- Get the belts that are connected to this one as inputs or outputs (depending on which pass we're doing).
                local ns = e.belt_neighbours[in_out]
                for _, n in pairs(ns) do
                    -- p.print(in_out.." belt_neighbor "..n.name.." at "..position_to_string(n.position))
                    draw_line(e, n, s, p, false)
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
                if e.type == 'underground-belt' then
                    local n = e.neighbours
                    if n ~= nil then
                        -- p.print("neighbor "..n.name.." at "..position_to_string(n.position))
                        if finished[finishkey(n)] == nil then
                            draw_line(e, n, s, p, true) -- dashed
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
            -- else
            --     p.print("Finished in "..num_steps.." steps.")
            end
        end
    end
    -- TODO: Put the print statements behind a verbose setting.
    -- p.print("Traced "..num_entities.." belts in "..num_steps.." steps.")
    -- TODO: Play a sound when the trace completes?
end) 