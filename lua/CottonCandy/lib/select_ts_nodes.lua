local lib_get_ts_nodes = require("CottonCandy.lib.get_ts_nodes")
local lib_select_mode = require("CottonCandy.lib.select_mode")

local M = {}

local select_node = function(node)
    local start_row, start_col, end_row, end_col = node:range()
    lib_select_mode.any_select({ start_row, start_col }, { end_row, end_col })
end

local node_covers_cursor = function(node, cursor_row, cursor_col)
    local start_row, start_col, end_row, end_col = node:range()

    if start_row ~= end_row and start_row <= cursor_row and end_row >= cursor_row then
        return true
    end

    if start_row == end_row and start_row == cursor_row then
        if start_col <= cursor_col and end_col >= cursor_col then
            return true
        end
    end

    return false
end

local sequential_jump = function(opts, nodes, cursor_row, cursor_col)
    if opts.direction == "next" then
        for _, node in ipairs(nodes) do
            local start_row, start_col, _, _ = node:range()
            if cursor_row == start_row and cursor_col < start_col then
                select_node(node)
                break
            end
            if not opts.current_line_only and (cursor_row < start_row) then
                select_node(node)
                break
            end
        end
    elseif opts.direction == "previous" then
        for i = #nodes, 1, -1 do
            local node = nodes[i]
            local start_row, start_col, _, _ = node:range()
            if cursor_row == start_row and cursor_col > start_col then
                select_node(node)
                break
            end
            if not opts.current_line_only and (cursor_row > start_row) then
                select_node(node)
                break
            end
        end
    end
end

--- content by ChatGPT
local find_smallest_node = function(nodes)
    -- Initialize smallest_row and smallest_col to large numbers
    local smallest_row = math.huge
    local smallest_col = math.huge

    -- Initialize smallest_node to nil
    local smallest_node = nil

    -- Loop through each node in the table
    for _, node in ipairs(nodes) do
        local start_row, start_col, end_row, end_col = node:range()

        -- Compute the number of rows and columns
        local num_rows = end_row - start_row + 1
        local num_cols = end_col - start_col + 1

        -- Update smallest_row and smallest_node if this node has fewer rows
        if num_rows < smallest_row then
            smallest_row = num_rows
            smallest_col = num_cols
            smallest_node = node

        -- If this node has the same number of rows as the current smallest_node, compare columns
        elseif num_rows == smallest_row and num_cols < smallest_col then
            smallest_col = num_cols
            smallest_node = node
        end
    end

    return smallest_node
end

local find_nodes_that_covers_cursor = function(nodes, cursor_row, cursor_col)
    local cutoff_index = 1
    local nodes_that_covers_cursor = {}

    for i, node in ipairs(nodes) do
        if node_covers_cursor(node, cursor_row, cursor_col) then
            table.insert(nodes_that_covers_cursor, node)
            cutoff_index = i
        end
    end

    return nodes_that_covers_cursor, cutoff_index
end

local vertical_drill_jump = function(opts, nodes, cursor_row, cursor_col)
    local nodes_that_covers_cursor, cutoff_index =
        find_nodes_that_covers_cursor(nodes, cursor_row, cursor_col)
    local smallest_node = find_smallest_node(nodes_that_covers_cursor)

    if smallest_node then
        local _, sn_start_col, _, sn_end_col = smallest_node:range()

        if opts.direction == "next" then
            for i = cutoff_index, #nodes do
                local node = nodes[i]
                local start_row, start_col, _, end_col = node:range()

                if start_row > cursor_row then
                    if
                        start_col >= sn_start_col and start_col <= sn_end_col
                        or end_col >= sn_start_col and end_col <= sn_end_col
                    then
                        select_node(node)
                        break
                    end
                end
            end
        end

        if opts.direction == "previous" then
            for i = cutoff_index, 1, -1 do
                local node = nodes[i]
                local start_row, start_col, _, end_col = node:range()

                if start_row < cursor_row then
                    if
                        start_col >= sn_start_col and start_col <= sn_end_col
                        or end_col >= sn_start_col and end_col <= sn_end_col
                    then
                        select_node(node)
                        break
                    end
                end
            end
        end
    end
end

M.select_node = function(opts)
    local nodes = lib_get_ts_nodes.get_nodes_from_query(opts.query)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_row, cursor_col = cursor[1] - 1, cursor[2]

    if opts.vertical_drill_jump then
        vertical_drill_jump(opts, nodes, cursor_row, cursor_col)
    else
        sequential_jump(opts, nodes, cursor_row, cursor_col)
    end
end

return M

-- {{{nvim-execute-on-save}}}
