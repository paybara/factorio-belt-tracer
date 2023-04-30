data:extend({
    {
        -- Keyboard shortcut to trace
        type = "custom-input",
        name = "paybara:trace-belt",
        key_sequence = "SHIFT + H",
        action = "lua",
        order = "a"
    },
    {
        -- Invisible entity to attach the traces to and color the map.
        type = "simple-entity",
        name = "paybara-belttracer-trace",
        picture = { filename = "__core__/graphics/empty.png", size = 1 },
        -- picture = {filename = "__belttracer__/graphics/dot.png", size=64},
        priority = "extra-high",
        flags = { "not-blueprintable", "not-deconstructable", "hidden", "not-flammable" },
        selectable_in_game = false,
        mined_sound = nil,
        minable = nil,
        collision_box = nil,
        selection_box = nil,
        collision_mask = {},
        render_layer = "explosion",
        vehicle_impact_sound = nil,
        tile_height = 1,
        tile_width = 1,
        -- TODO: Figure out how to get traces to show on the map.
        friendly_map_color = { 1, 1, 1 }, -- white
        map_color = { 1, 1, 1 },
    },
})
