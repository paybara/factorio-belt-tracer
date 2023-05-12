local function position_to_string(p)
    return '[' .. p.x .. ',' .. p.y .. ']'
end

local function is_transport_line(e)
    local belt_types = { 'transport-belt', 'splitter', 'underground-belt' }
    for _, belt_type in pairs(belt_types) do
        if e.type == belt_type then
            return true
        end
    end
    return false
end

local function is_pipe(e)
    -- If it has a fluid box then we can trace it.
    return #(e.fluidbox) > 0
end

local global_prefix = "paybara-belt-tracer-"

local function global_entities(player)
    return global_prefix .. player.name .. "-entities"
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
    local e = global[global_entities(player)][pos_str]
    if e == nil then
        e = s.create_entity({
            name = 'paybara-belttracer-trace',
            position = pos,
        })
        global[global_entities(player)][pos_str] = e
    end
    return e
end

local white = { 1, 1, 1 }

local line_thickness = 1


-- from_offset and to_offset are 2-element arrays with the x and y components.
local function draw_line_offset(from, from_offset, to, to_offset, s, player, color, dashed)
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
    rendering.draw_line({
        ["from"] = from,
        ["from_offset"] = from_offset,
        ["to"] = to,
        ["to_offset"] = to_offset,
        -- TODO: Customize colors.
        ["color"] = color,
        ["width"] = line_thickness, -- pixels
        ["surface"] = s,            -- Draw on whatever surface the belts are on.
        ["players"] = { player },   -- Only draw for the current player
        ["dash_length"] = dash,
        ["gap_length"] = gap
    })
end

-- Draw a line between two entities, on surface s, visible to player.
local function draw_line(from, to, s, player, color, dashed)
    draw_line_offset(from, { 0, 0 }, to, { 0, 0 }, s, player, color, dashed)
end

-- Draw a small circle on entity e, on surface s, visible to player.
local function draw_circle(e, s, player)
    -- Get or create a hidden entity at this location and draw the circle attached to it.
    -- That way the trace gets cleaned up if the mod is disabled.
    e = get_trace_entity(player, s, e.position)
    rendering.draw_circle({
        ["target"] = e,
        ["radius"] = .3,
        -- TODO: Customize colors.
        ["color"] = { 1, 1, 1 },    --white
        ["width"] = line_thickness, -- pixels
        ["filled"] = false,
        ["surface"] = s,            -- Draw on whatever surface the belts are on.
        ["players"] = { player },   -- Only draw for the current player
    })
end

-- Draw half of a circle on entity e, on surface s, visible to player.
local function draw_half_dot(e, e_offset, s, player, color, top)
    local pi = 3.1415
    local start_angle = 0
    if top == true then
        start_angle = start_angle + pi
    end
    e = get_trace_entity(player, s, e.position)
    rendering.draw_arc({
        ["target"] = e,
        ["target_offset"] = e_offset,
        ["max_radius"] = .15,
        ["min_radius"] = 0,
        ["angle"] = pi,
        ["start_angle"] = start_angle,
        -- TODO: Customize colors.
        ["color"] = color,
        ["width"] = line_thickness, -- pixels
        ["surface"] = s,            -- Draw on whatever surface the belts are on.
        ["players"] = { player },   -- Only draw for the current player
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
    for _, in_out in pairs({ "inputs", "outputs" }) do
        -- Start from the selected entity both times.
        local to_be_walked = { e }
        -- Clear the finished list between passes:
        -- if something is both an input and an output it needs to be traversed both times.
        local finished = { [finishkey(e)] = true }
        local keep_going = true
        while keep_going do
            local next_pass = {}
            local num_next = 0
            keep_going = false
            for _, edge in pairs(to_be_walked) do
                -- Get the belts that are connected to this one as inputs or outputs (depending on which pass we're doing).
                for _, n in pairs(edge.belt_neighbours[in_out]) do
                    -- p.print(in_out.." belt_neighbor "..n.name.." at "..position_to_string(n.position))
                    draw_line(edge, n, s, p, white, false)
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
                            draw_line(edge, n, s, p, white, true) -- dashed
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
        p.print("Traced " .. num_entities .. " belts in " .. num_steps .. " steps.")
    end
    -- TODO: Play a sound when the trace completes?
end

local function box_index(fb, i)
    local ret = {}
    ret["fb"] = fb
    ret["i"] = i
    return ret
end

-- For debugging: print a concise description of a FluidBox object
local function fbToStr(fb)
    local str = #(fb) .. " boxes in " .. fb.owner.name .. ": "
    for i = 1, #(fb) do
        local fluid = ""
        local lockedFluid = fb.get_locked_fluid(i)
        if lockedFluid ~= nil then
            fluid = "(" .. lockedFluid .. ")"
        end
        local conns = fb.get_connections(i)
        local connStr = ""
        if #(conns) == 0 then
            connStr = "nothing"
        else
            connStr = "["
            for j = 1, #(conns) do
                if j > 1 then
                    connStr = connStr .. ","
                end
                connStr = connStr .. conns[j].owner.name
            end
            connStr = connStr .. "]"
        end
        str = str .. " " .. fb.get_fluid_system_id(i) .. fluid .. "->" .. connStr
    end
    return str
end

-- trace_pipe traces pipes and other entities that hold fluid by walking their fluidbox connections.
local function trace_pipe(p, e, verbose)
    local s = e.surface

    -- Leave a circle at the selected tile so you can see where you traced from.
    draw_circle(e, s, p)

    local orig_fb = e.fluidbox

    -- Gather all of the fluid boxes of the selected entity. Start tracing from each box.
    --
    -- Only trace each fluid _system_ once from the starting entity.
    -- e.g. if something is connected to the same fluid system via multiple connections
    -- (like both outputs from a chem plant or a pipe looping back on itself)
    -- then tracing each system once is sufficient.
    local fluid_systems = {}
    local num_systems = 0
    for i = 1, #(orig_fb) do
        local system = orig_fb.get_fluid_system_id(i)
        if system ~= nil and fluid_systems[system] == nil then
            fluid_systems[system] = i
            num_systems = num_systems + 1
        end
    end
    if verbose then
        p.print("Found " .. num_systems .. " different system(s) to trace.")
    end

    local num_entities = 1
    local num_steps = 1

    -- Trace each fluid system from the fluid box in the original entity.
    for system, i in pairs(fluid_systems) do
        local fluid_name = ""
        local finished = { [finishkey(orig_fb.owner)] = true }
        -- to_be_walked and next_pass are arrays of structs containing the elements:
        --   "fb" (for fluidbox)
        --   "i" (for index into the fluidbox, since the fluidbox is itself an array.)
        local to_be_walked = { box_index(orig_fb, i) }
        local keep_going = true
        -- while keep_going and num_steps < 3 do
        while keep_going do
            keep_going = false
            local next_pass = {}
            local num_next = 0
            for _, fbi in pairs(to_be_walked) do
                -- For each fluidbox+index that still needs to be walked...
                local fb = fbi.fb
                local from = fb.owner

                -- Record the name of the first fluid encountered, so we can highlight where fluids are mixing.
                if fluid_name == "" and fb[fbi.i] ~= nil then
                    fluid_name = fb[fbi.i].name
                    if verbose then
                        p.print("Tracing #" .. fbi.i .. " of " .. fbToStr(fb) .. " with fluid " .. fluid_name)
                    end
                end

                -- Get all of that box's connections.
                for _, connFB in pairs(fb.get_connections(fbi.i)) do
                    local to = connFB.owner
                    local fluid_change = false
                    if fluid_name ~= "" then
                        for j = 1, #(connFB) do
                            if connFB.get_fluid_system_id(j) == system and connFB[j] ~= nil and connFB[j].name ~= fluid_name then
                                fluid_change = true
                                if verbose then
                                    p.print("Detected fluid_change from " ..
                                        fluid_name .. " to " .. connFB[j].name .. " at " .. to.name)
                                end
                                break
                            end
                        end
                    end

                    -- Draw a line from the entity owning this fluid box to each connection.
                    -- Queue each fluidbox+index that we haven't visited yet to be walked next pass.
                    local dashed = false
                    if from.type == "pipe-to-ground" and to.type == "pipe-to-ground" then
                        dashed = true
                    end

                    if not dashed or finished[finishkey(to)] == nil then
                        -- Draw lines even if we've already visited entities, to fill in grids of pipes or tanks.
                        -- Just don't double-draw dashed lines, as that can mess them up.
                        local color = white
                        if fluid_change then
                            color = { 1, 0, 0 }
                        end
                        draw_line(from, to, s, p, color, dashed)
                    end
                    if finished[finishkey(to)] == nil and not fluid_change then
                        for j = 1, #(connFB) do
                            if connFB.get_fluid_system_id(j) == system then
                                -- connFB is all the fluid boxes in the connected entity, trace all of its fluid boxes in the same system.
                                num_next = num_next + 1
                                next_pass[num_next] = box_index(connFB, j)
                                -- p.print("Next: #" .. j .. " of " .. fbToStr(connFB))
                            end
                        end
                        finished[finishkey(to)] = true
                    end
                end
            end
            if num_next > 0 then
                to_be_walked = next_pass
                keep_going = true
                num_steps = num_steps + 1
                num_entities = num_entities + num_next
            end
        end
    end

    if verbose then
        p.print("Traced " .. num_entities .. " pipes in " .. num_steps .. " steps.")
    end
end

local function has_wires(e)
    if e.circuit_connection_definitions == nil then
        return false
    end
    return #(e.circuit_connection_definitions) > 0
end

-- For debugging: Print wire-related information about an entity.
local function wire_info(e)
    local str = #e.circuit_connection_definitions .. " connected entities:"
    for i, circuit in pairs(e.circuit_connection_definitions) do
        str = str .. '\n' .. i .. ': '
        if circuit == nil then
            str = str .. "<nil circuit>"
        else
            local wire = "nil"
            if circuit.wire ~= nil then
                wire = circuit.wire
            end
            str = str .. 'wire:' .. wire
            local entity = "nil"
            if circuit.target_entity ~= nil then
                entity = circuit.target_entity.name
            end
            str = str .. ", to: " .. entity
            local source_circuit_id = "nil"
            if circuit.source_circuit_id ~= nil then
                source_circuit_id = circuit.source_circuit_id
            end
            str = str .. ", source_circuit_id: " .. source_circuit_id
            local target_circuit_id = "nil"
            if circuit.target_circuit_id ~= nil then
                target_circuit_id = circuit.target_circuit_id
            end
            str = str .. ", target_circuit_id: " .. target_circuit_id
        end
    end
    return str
end

-- connected_entity returns a tuple for an entity and a circuit_id that's connected to it,
-- representing a wire connected to a specific connection point on an entity.
local function connected_entity(e, id)
    local ret = {}
    ret["e"] = e
    ret["id"] = id
    return ret
end

local function direction_string(d)
    if d == defines.direction.north then
        return "north"
    elseif d == defines.direction.northeast then
        return "northeast"
    elseif d == defines.direction.east then
        return "east"
    elseif d == defines.direction.southeast then
        return "southeast"
    elseif d == defines.direction.south then
        return "south"
    elseif d == defines.direction.southwest then
        return "southwest"
    elseif d == defines.direction.west then
        return "west"
    elseif d == defines.direction.northwest then
        return "northwest"
    end
    return "unknown direction"
end



local function connection_offset(e, circuit_id, wire_type, p)
    -- TODO: Draw lines from the connection points for all entities
    --       Requested API at https://forums.factorio.com/viewtopic.php?f=28&t=106044

    local combinator_offset_vectors = {
        [defines.circuit_connector_id.combinator_input] = {
            [defines.direction.east] = { -1, 0 },
            [defines.direction.south] = { 0, -1 },
        },
        [defines.circuit_connector_id.combinator_output] = {
            [defines.direction.north] = { 0, -1 },
            [defines.direction.west] = { -1, 0 },
        },
    }

    local offset = { 0, 0 }

    -- This just hacks in support for the two vanilla combinators.
    if e.name == 'arithmetic-combinator' or e.name == 'decider-combinator'
    then
        local combinator_offset = combinator_offset_vectors[circuit_id][e.direction]
        if combinator_offset ~= nil then
            offset = combinator_offset
        end
    end
    return offset
end

local function line_offset(offset, wire_type)
    -- Red to the north, green to the south.
    if wire_type == defines.wire_type.green then
        offset[2] = offset[2] + .1
    else
        offset[2] = offset[2] - .1
    end
    return offset
end

-- Intended to be called twice, once to draw lines and then again to draw the dots on top.
local function trace_wires(p, e, verbose, drawDots)
    if verbose then
        p.print('Tracing wires for ' .. e.name .. ' (facing ' .. direction_string(e.direction) .. '): ' .. wire_info(e))
    end

    local s = e.surface
    -- Leave a circle at the selected tile so you can see where you traced from.
    draw_circle(e, s, p)

    -- Set up the different groups to trace separately: each color from each connection point.
    local wire_networks = {}
    for i, circuit in pairs(e.circuit_connection_definitions) do
        local wire_color = circuit.wire
        if wire_networks[wire_color] == nil then
            wire_networks[wire_color] = {}
        end
        local connections = wire_networks[wire_color]
        local circuit_id = circuit.source_circuit_id
        if connections[circuit_id] == nil then
            connections[circuit_id] = connected_entity(e, circuit_id)
        end
    end

    for wire_color, entities_by_circuit_id in pairs(wire_networks) do
        local color = { .9, 0, 0 } -- red
        local dot_top = true
        if wire_color == defines.wire_type.green then
            color = { 0, .9, 0 }
            dot_top = false
        end
        for circuit_id, e_id in pairs(entities_by_circuit_id) do
            local finished = { [finishkey(e)] = true }
            local to_be_walked = { e_id }
            while #to_be_walked > 0 do
                local next_pass = {}
                for _, from_id in pairs(to_be_walked) do
                    local from = from_id.e
                    for _, circuit in pairs(from.circuit_connection_definitions) do
                        if circuit.wire == wire_color and circuit.source_circuit_id == from_id.id then
                            local from_offset = connection_offset(from, from_id.id, p)
                            local to = circuit.target_entity
                            if drawDots then
                                draw_half_dot(from, from_offset, s, p, color, dot_top)
                            else
                                draw_line_offset(from, line_offset(from_offset, wire_color),
                                    to, line_offset(connection_offset(to, circuit.target_circuit_id, p), wire_color),
                                    s, p, color, false)
                            end
                            if finished[finishkey(to)] == nil then
                                next_pass[#next_pass + 1] = connected_entity(to, circuit.target_circuit_id)
                                finished[finishkey(to)] = true
                            end
                        end
                    end
                end
                to_be_walked = next_pass
            end
        end
    end
end

-- local function dump(o)
--     if type(o) == 'table' then
--         local s = '{ '
--         for k, v in pairs(o) do
--             if type(k) ~= 'number' then k = '"' .. k .. '"' end
--             s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
--         end
--         return s .. '} '
--     else
--         return tostring(o)
--     end
-- end

-- This is the main handler function, it runs whenever the trace action is triggered.
script.on_event('paybara:trace-belt', function(event)
    local p = game.players[event.player_index]
    local e = p.selected
    local verbose = settings.get_player_settings(event.player_index)["belttracer-verbose-logging"].value
    line_thickness = settings.get_player_settings(event.player_index)["belttracer-line-thickness"].value

    if e and verbose then
        for _, over in pairs(e.surface.find_entities_filtered({ position = e.position })) do
            p.print("Over entity " .. over.name .. " of type " .. over.type)
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
    elseif is_pipe(e) then
        trace_pipe(p, e, verbose)
    end
    -- Draw wires last to put the dots on top.
    if has_wires(e) then
        -- Draw lines
        trace_wires(p, e, verbose, false)
        -- ...then draw dots
        trace_wires(p, e, verbose, true)
    end
end)
