-- Ported from https://github.com/ocornut/imgui/issues/3606#issuecomment-731580081
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

-- Script control variables
local terminate = false

-- UI Control variables
local isOpen, shouldDraw = true, true

--[[
using V=ImVec2;using I=int;using F=float;using B=bool;
#define T static
#define W 320
#define H 180
#define FR(i,m) for(I i=0;i<m;++i)
#define A d->AddRectFilled
struct B2{
    ImVec2 l,h;
    bool a=1;
    int c=~0;
    bool in(ImVec2 p){
        return(p.x>l.x&&p.x<h.x)&&(p.y>l.y&&p.y<h.y);
    }
};
void FX(ImDrawList* d,V a,V b,V s,ImVec4 m,float t) {
    static bool re=1;
    static float cx,cy,r,vx,vy;
    static float lt=t;
    static float dt=0;
    static float bw=W/10;
    static float bh=H/12;
    static B2 br[60];
    static B2 p{{0,b.y-5},{0,b.y}};
    if(re){
    cx=a.x+W/2;
    cy=a.y+H-8;
    r=3;
    vx=-1;
    vy=-3;
    FR(i,6)
        FR(j,10){
            B2& b=br[j+i*10];
            b.a=1;
            b.l={a.x+j*bw,a.y+i*bh};
            b.h={a.x+(j+1)*bw,a.y+(i+1)*bh};
            b.c=255<<24|rand();
        }
        re=0;
    }
    FR(i,60){
        B2& b=br[i];
        if(!b.a)
            continue;
        if(!b.in({cx,cy}))
            continue;
        b.a=0;
        float ol=cx-b.l.x;
        float or=b.h.x-cx;
        float ot=cy-b.l.y;
        float ob=b.h.y-cy;
        float ox=min(ol,or);
        float oy=min(ot,ob);
        bool lo=ol<ob;
        bool to=ot<ob;
        ox<oy?vx=-vx:vy=-vy;
    }
    dt=t-lt;
    lt=t;
    p.l.x=a.x+m.x*s.x-20;
    p.h.x=p.l.x+40;
    if(p.in({cx,cy}))
        vy=-vy;
    FR(i,60){
        B2& b=br[i];
        if(b.a)
            d->AddRectFilled(b.l,b.h,b.c);
    }
    d->AddRectFilled(p.l,p.h,~0);
    d->AddCircleFilled({cx,cy},r,~0);
    cx+=vx*dt*30;
    cy+=vy*dt*30;
    if(cx<a.x||cx>b.x)
        vx=-vx;
    if(cy<a.y)
        vy=-vy;
    if (!m.w)
        re=1;
}
]]
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

local restart_timer = nil
local flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoFocusOnAppearing,
        ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.NoResize)
local function updateImGui()
    if not isOpen then return end
    ImGui.SetNextWindowSize(width,height)
    isOpen, shouldDraw = ImGui.Begin('###arkanoid', isOpen, flags)
    if shouldDraw then
        local draw_list = ImGui.GetWindowDrawList()

        local p0x, p0y = ImGui.GetItemRectMin()
        local mousepos = ImGui.GetMousePosVec()

        if restart_timer and restart_timer+3000 < mq.gettime() then
            remaining = 60
            gameover = false
            should_reset = true
            restart_timer = nil
        end
        if not gameover then
            DrawArkanoid(draw_list, ImVec2(p0x, p0y), mousepos, ImGui.GetTime())
        elseif not restart_timer and ImGui.Button('Play Again?') then
            restart_timer = mq.gettime()
        elseif restart_timer then
            ImGui.Text('New game starting in %.02f seconds!', 3-(mq.gettime()-restart_timer)/1000)
        end
    end
    ImGui.End()
end

mq.imgui.init('arkanoid', updateImGui)

while not terminate do
    mq.delay(1000)
end