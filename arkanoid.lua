-- Ported from https://github.com/ocornut/imgui/issues/3606#issuecomment-731580081
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

-- Script control variables
local terminate = false

-- UI Control variables
local isOpen, shouldDraw = true, true

local width = 320
local height = 205

local gameover = false
local remaining = 60
local should_reset = true
local cx,cy,r,vx,vy
local lt = 0
local dt = 0
local block_width = width/10
local block_height = height/12
local blocks = {}
local pad = {l=ImVec2(0,0), h=ImVec2(0,0)}

local function Reset(a)
    -- reset the game
    cx = a.x + width/2
    cy = a.y + height - 50
    r = 3
    vx = -1
    vy = -3
    for i=0,5 do
        for j=1,10 do
            local block = blocks[j+(i*10)]
            if not block then block = {} blocks[j+(i*10)] = block end
            block.a = true
            block.l = ImVec2(a.x+(j-1)*block_width, a.y+25+i*block_height)
            block.h = ImVec2(a.x+j*block_width, a.y+25+(i+1)*block_height)
            block.c = ImGui.GetColorU32(math.random(1,254)/255, math.random(1,254)/255, math.random(1,254)/255, 1)
        end
        should_reset = false
    end
end

local function DisableBlock(block)
    -- a block was hit, delete it and adjust the balls direction
    block.a = false
    remaining = remaining-1
    local o_l = cx-block.l.x
    local o_r = block.h.x-cx
    local o_t = cy-block.l.y
    local o_b = block.h.y-cy
    local o_x = math.min(o_l, o_r)
    local o_y = math.min(o_t, o_b)
    if o_x < o_y then vx = -vx else vy = -vy end
end

local function IsBallInRect(b, vec)
    return vec.x > b.l.x and vec.x < b.h.x and vec.y > b.l.y and vec.y < b.h.y
end

local function DrawShapes(draw_list)
    for i=1,60 do
        local block = blocks[i]
        if block.a then
            draw_list:AddRectFilled(block.l, block.h, block.c)
        end
    end
    draw_list:AddRectFilled(pad.l, pad.h, ImGui.GetColorU32(ImVec4(1.0, 1.0, 0.4, 1.0)))
    draw_list:AddCircleFilled(ImVec2(cx, cy), r, ImGui.GetColorU32(ImVec4(1.0, 1.0, 0.4, 1.0)), 6)
end

local function UpdateBallPosition(a)
    local oldcx = cx
    local oldcy = cy
    cx = cx + (vx*dt*30)
    cy = cy + (vy*dt*30)
    if cx < a.x or cx > a.x+width then
        vx = -vx
        cx = oldcx
    end
    if cy < a.y then
        vy = -vy
        cy = oldcy
    end
    if IsBallInRect(pad, ImVec2(cx, cy)) then
        -- the ball hit the pad, reverse its direction
        vy = -vy
        cy = oldcy
    end
end

local function DrawArkanoid(draw_list, a, m, t)
    pad.l = ImVec2(0, a.y+height-5)
    pad.h = ImVec2(0, a.y+height)
    if should_reset then
        Reset(a)
    end
    for i=1,60 do
        local block = blocks[i]
        if block.a and IsBallInRect(block, ImVec2(cx,cy)) then
            DisableBlock(block)
        end
    end
    pad.l.x = m.x-20
    pad.h.x = pad.l.x+40
    -- draw all the pieces
    DrawShapes(draw_list)
    dt = t-lt
    lt = t
    -- calculate ball position only when mouse is within the window
    -- also only when dt < 1 as starting new game for some reason causes it to be a large value
    if m.x > a.x and m.x < a.x+width and m.y > a.y and m.y < a.y+height and dt < 1 then
        UpdateBallPosition(a)
    end
    if cy > a.y+height+20 or remaining == 0 then
        gameover = true
    end
end

local start = true
local oldpos0x, oldpos0y
local restart_timer = nil
local flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoFocusOnAppearing,
        ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.NoResize)
local function updateImGui()
    if not isOpen then return end
    ImGui.SetNextWindowSize(width,height)
    isOpen, shouldDraw = ImGui.Begin('###arkanoid', isOpen, flags)
    if shouldDraw then
        local draw_list = ImGui.GetWindowDrawList()

        local x,y = ImGui.GetItemRectMin()
        if x ~= oldpos0x or y ~= oldpos0y then
            if not start then gameover = true end
            oldpos0x = x
            oldpos0y = y
        end
        local mousepos = ImGui.GetMousePosVec()

        if restart_timer and restart_timer+1000 < mq.gettime() then
            remaining = 60
            gameover = false
            should_reset = true
            restart_timer = nil
        end
        if start then
            if ImGui.Button('Play') then
                start = false
                gameover = true
                restart_timer = mq.gettime()
            end
        elseif not gameover then
            DrawArkanoid(draw_list, ImVec2(x, y), mousepos, ImGui.GetTime())
        elseif not restart_timer and ImGui.Button('Play Again?') then
            restart_timer = mq.gettime()
        elseif restart_timer then
            ImGui.Text('New game starting in %.02f seconds!', 1-(mq.gettime()-restart_timer)/1000)
        end
    end
    ImGui.End()
end

mq.imgui.init('arkanoid', updateImGui)

while not terminate do
    mq.delay(1000)
end