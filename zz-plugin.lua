local api = ...

local M = {}

local size
local background = resource.create_colored_texture(0, 0, 0, 0)
local active_scroller, next_scroller

local function Scroller(items, font, speed)
    local total_w = 0
    for _, item in ipairs(items) do
        total_w = total_w + item.width
    end

    local function draw(now, y, x1, x2, all_alpha)
        if #items == 0 then
            return
        end
        local x = math.floor(x1 + (now * -speed) % total_w - total_w)
        local idx = 1
        
        local render = 0
        while x < x2 do
            local item = items[idx]
            if x + item.width < x1 then
                -- skip: not on screen
            else
                local item_alpha = item.color.a
                if item.effect == "blink" then
                    item_alpha = math.min(1, 1-math.sin(now*10)) * item_alpha
                end
                local a = item_alpha * all_alpha
                render = render + 1
                font:write(
                    x, y, item.text, size,
                    item.color.r, item.color.g, item.color.b, a
                )
            end
            x = x + item.width
            idx = idx + 1
            if idx > #items then
                idx = 1
            end
        end
    end

    return draw
end

active_scroller = Scroller({})

function M.updated_config_json(config)
    local items = {}
    for idx = 1, #config.texts do
        local item = config.texts[idx]
        local color = config.color
        if item.color.a ~= 0 then
            color = item.color
        end
        if config.background_color.a > 0 then
            background = resource.create_colored_texture(unpack(config.background_color.rgba))
        else
            background = nil
        end

        -- 'show' either absent or true?
        if item.show ~= false then
            items[#items+1] = {
                text = item.text,
                effect = item.effect,
                color = color,
            }
            items[#items+1] = {
                text = "   -   ",
                blink = false,
                color = config.color,
            }
        end
    end
    size = config.size
    local font = resource.load_font(api.localized(
        config.font.asset_name
    ))
    for _, item in ipairs(items) do
        item.width = font:width(item.text, size)
    end
    active_scroller = Scroller(
        items, font, config.speed
    )
    print("configured scroller content")
end

local function instance(ctx)
    local pos = ctx.child_config.pos or 'bottom'
    local overlap = ctx.child_config.overlap or 'overlap'

    local function layout(canvas)
        if overlap == 'overlap' then
            return canvas:full()
        elseif pos == 'bottom' then
            return canvas:cut('bottom', size * ctx.reveal)
        else
            return canvas:cut('top', size * ctx.reveal)
        end
    end

    local function draw(canvas, target)
        local y, a
        if overlap == 'overlap' then
            a = ctx.reveal
            if pos == "bottom" then
                y = target.y2 - size
            else
                y = target.y1
            end
        else
            a = 1
            if pos == "bottom" then
                y = target.y2 - size * ctx.reveal
            else
                y = target.y1 - size * (1 - ctx.reveal)
            end
        end
        if background then
            background:draw(target.x1, y, target.x2, y + size)
        end
        active_scroller(
            api.wall_time(), y, target.x1, target.x2, a
        )
    end

    return {
        layout = layout;
        draw = draw;
    }
end

function M.merge_info(ctx)
    return {
        overlap = ctx.child_config.overlap,
    }
end

function M.init(...)
    return instance(...)
end

return M
