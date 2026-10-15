--[[
    ╦ ╦╦ ╦╔═╗╔═╗╦═╗╔╦╗
    ╠═╣╚╦╝╠═╝║╣ ╠╦╝ ║║    HYPERD  v4.0  —  everything in ONE script
    ╩ ╩ ╩ ╩  ╚═╝╩╚══╩╝

    Script (NOT a LocalScript)  →  ServerScriptService

    SETUP
      1. Create a normal Script in ServerScriptService and paste this whole file.
      2. Put your UserId in OWNER SETTINGS just below (Studio testers are owners automatically).
      3. That's it. You get the panel when you join.

    HOW IT WORKS
      The top half runs on the server: it knows who the owners are, saves who has the
      panel, and handles give / remove / bring. When someone is given the panel, the
      script copies itself into their PlayerGui as a client-side Script, and the bottom
      half (the panel) runs on their screen.

    ENHANCEMENTS (hacker tab)
      Clicking Enhancements plays an 8-second hacker cutscene (press Space or SKIP to
      skip it), then opens the tab. No PIN needed. It holds the VIP aimbot, wall shot,
      radar, blink dash, server heal, terminal, X-ray, freecam, anti-void and more.
      By default every player who has the panel gets the VIP perks (EveryoneVIP in
      OWNER SETTINGS); set EveryoneVIP = false to limit the server-side perks to owners.

    v4.0 TOOLS
      The Tools tab gives real server-made items: Bat (knockback + ragdoll), Fling
      Launcher, Freeze Ray, Teleport Wand, Speed Coil, Gravity Coil and Heal Wand.
      By default only owners can give tools (ToolsOwnersOnly in OWNER SETTINGS); owners
      can also give tools to other players and use the new moderation tools in the
      Admin tab (announce, kick, freeze, heal, lock server).
      Wall shot and the other Enhancements features no longer need VIP.

    GIVE THE PANEL
      • Open the panel → Admin tab → GIVE next to any player (or Give everyone).
      • Or chat (owners only):  ;give <name|me|all|others>   ;remove <name|all>
                                ;bring <name|all|others>      ;list    ;help
        Chat commands are visible to the whole server — the Admin tab is private.

    Everything the server does is re-checked on the server; players cannot give
    themselves the panel. Do not put secrets (API keys, webhooks) in this file, because
    the client copy of the script contains this same text.
    Optional: enable Game Settings > Security > "Enable Studio Access to API Services"
    so grants are saved while testing in Studio.

    Intended for your own experience.
]]

-- (Unused now: the Enhancements tab no longer asks for a PIN.)
local VIP_PIN = "0000"

if game:GetService("RunService"):IsServer() then
    ------------------------------------------------------------------
    -- ═══════════════ OWNER SETTINGS & SERVER LOGIC ═══════════════
    ------------------------------------------------------------------
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local DataStoreService = game:GetService("DataStoreService")
    local RunService = game:GetService("RunService")

    ----------------------------------------------------------------------
    -- CONFIG
    ----------------------------------------------------------------------
    local CONFIG = {
        OwnerUserIds = {
            -- 12345678,   -- ← put your UserId here (add more lines for co-owners)
        },
        UseGameCreator = true,        -- the user who created the place counts as an owner
        StudioAlwaysOwner = true,     -- anyone testing in Studio counts as an owner

        -- Optional: treat group members at or above a rank as owners (0 = off)
        GroupId = 0,
        GroupMinRank = 255,

        PanelName = "HyperdPanel",    -- name given to the copy that is placed in a player's PlayerGui
        OwnersAlwaysHavePanel = true, -- owners receive the panel automatically on join
        OwnersCanBeRevoked = false,

        SaveGrants = true,            -- remember granted players across sessions (DataStore)
        DataStoreName = "HyperdGrants_v1",

        Prefix = ";",                 -- chat command prefix

        -- VIP / ENHANCEMENTS (the PIN is checked on the server)
        VipPin = VIP_PIN,
        VipMaxAttempts = 5,           -- wrong PINs before a temporary lockout
        VipLockSeconds = 30,
        EveryoneVIP = true,           -- true = everyone who has the panel gets the VIP perks (no PIN)
        OwnersAutoVIP = true,         -- owners always get the VIP perks

        AllowWallShot = true,         -- lets anyone with the panel hit locked targets through walls
        WallShotDamage = 20,
        WallShotCooldown = 0.25,      -- seconds between shots (enforced here)
        WallShotRange = 600,          -- studs
        WallShotIgnoreTeam = true,
        VipHealCooldown = 20,

        -- TOOLS (bat, fling launcher, freeze ray, teleport wand, coils, heal wand)
        ToolsOwnersOnly = true,        -- true = only owners can give themselves tools; false = anyone with the panel can
        ToolsProtectOwners = true,     -- tools never push, freeze or hit owners
        ToolsProtectForceField = true, -- tools never affect players who have a ForceField (spawn protection)
        ToolCooldown = 0.6,            -- seconds between uses of any tool
        KeepToolsOnRespawn = true,
        BatRange = 9,                  -- studs
        BatKnockback = 80,             -- default knockback speed (players can raise it up to BatKnockbackMax)
        BatKnockbackMax = 250,
        BatDamage = 0,                 -- extra damage per bat hit (0 = none)
        RagdollTime = 3,               -- seconds a hit player stays ragdolled
        RagdollTimeMax = 10,
        FlingPower = 220,              -- fling launcher speed
        FlingPowerMax = 500,
        FlingRange = 90,               -- studs
        FlingRangeMax = 300,
        FreezeTime = 4,                -- seconds the freeze ray holds a player
        FreezeTimeMax = 15,
        HealWandAmount = 35,
        RegenMax = 10,                 -- most health per second a player can give themselves

    }

    ----------------------------------------------------------------------
    -- SETUP
    ----------------------------------------------------------------------
local remote=ReplicatedStorage:FindFirstChild("HyperdRemote")
if not remote then
remote=Instance.new("RemoteEvent")
remote.Name="HyperdRemote"
remote.Parent=ReplicatedStorage
end
local store
if CONFIG.SaveGrants then
local ok,ds=pcall(function()return DataStoreService:GetDataStore(CONFIG.DataStoreName)end)
if ok then store=ds end
end
local ownerSet={}
for _,id in ipairs(CONFIG.OwnerUserIds)do ownerSet[id]=true end
local groupCache={}
local function isOwner(player)
if ownerSet[player.UserId]then return true end
if CONFIG.StudioAlwaysOwner and RunService:IsStudio()then return true end
if CONFIG.UseGameCreator and game.CreatorType==Enum.CreatorType.User
and game.CreatorId==player.UserId then
return true
end
if CONFIG.GroupId>0 then
local cached=groupCache[player.UserId]
if cached~=nil then return cached end
local ok,rank=pcall(function()return player:GetRankInGroup(CONFIG.GroupId)end)
if ok then
groupCache[player.UserId]=rank>=CONFIG.GroupMinRank
return groupCache[player.UserId]
end
end
return false
end
local function hasAccess(player)
return player:GetAttribute("HyperdAccess")==true
end
local function notifyClient(player,title,message,kind)
remote:FireClient(player,"notify",title,message,kind or "info")
end
local function removeClone(player)
local pg=player:FindFirstChild("PlayerGui")
if not pg then return end
for _,child in ipairs(pg:GetChildren())do
if child.Name==CONFIG.PanelName and child:IsA("Script")then
child:Destroy()
end
end
end
local function deliver(player)
local pg=player:FindFirstChild("PlayerGui")or player:WaitForChild("PlayerGui",10)
if not pg then return false end
if pg:FindFirstChild(CONFIG.PanelName)then return true end
local clone=script:Clone()
clone.Name=CONFIG.PanelName
clone.RunContext=Enum.RunContext.Client
clone.Disabled=false
clone:SetAttribute("Delivered",true)
clone.Parent=pg
return true
end
local function save(player,value)
if not store then return end
task.spawn(function()
local key=tostring(player.UserId)
pcall(function()
if value then
store:SetAsync(key,true)
else
store:RemoveAsync(key)
end
end)
end)
end
local function grant(player,by)
local owner=isOwner(player)
player:SetAttribute("HyperdOwner",owner)
player:SetAttribute("HyperdAccess",true)
if player:GetAttribute("HyperdVIP")==nil then
player:SetAttribute("HyperdVIP",CONFIG.EveryoneVIP==true or(owner and CONFIG.OwnersAutoVIP)or false)
end
if not deliver(player)then
player:SetAttribute("HyperdAccess",false)
return false
end
if not owner then save(player,true)end
if by and by~=player then
notifyClient(player,"HYPERD",by.DisplayName .. " gave you the panel.","good")
end
return true
end
local function revoke(player)
if isOwner(player)and not CONFIG.OwnersCanBeRevoked then return false end
player:SetAttribute("HyperdAccess",false)
player:SetAttribute("HyperdVIP",false)
save(player,false)
task.delay(2.5,function()
if player.Parent and not hasAccess(player)then removeClone(player)end
end)
return true
end
local function findPlayers(query,sender)
query=string.lower(query or "")
if query=="me" then return{sender}end
if query=="all" then return Players:GetPlayers()end
if query=="others" then
local list={}
for _,p in ipairs(Players:GetPlayers())do
if p~=sender then table.insert(list,p)end
end
return list
end
if query=="" then return{}end
local exact,prefix={},{}
for _,p in ipairs(Players:GetPlayers())do
local n,d=string.lower(p.Name),string.lower(p.DisplayName)
if n==query or d==query then
table.insert(exact,p)
elseif string.sub(n,1,#query)==query or string.sub(d,1,#query)==query then
table.insert(prefix,p)
end
end
return#exact>0 and exact or prefix
end
local function nameList(list)
local t={}
for _,p in ipairs(list)do table.insert(t,p.DisplayName)end
return#t>0 and table.concat(t,", ")or "nobody"
end
local function bring(target,owner,angle)
if target==owner then return false end
local oRoot=owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
local tChar=target.Character
if not oRoot or not tChar or not tChar:FindFirstChild("HumanoidRootPart")then return false end
local dir=angle and Vector3.new(math.cos(angle),0,math.sin(angle))or oRoot.CFrame.LookVector
local pos=oRoot.Position+dir*5+Vector3.new(0,1.5,0)
tChar:PivotTo(CFrame.lookAt(pos,Vector3.new(oRoot.Position.X,pos.Y,oRoot.Position.Z)))
notifyClient(target,"HYPERD",owner.DisplayName .. " teleported you.","info")
return true
end
local function bringMany(list,owner)
local others={}
for _,p in ipairs(list)do
if p~=owner then table.insert(others,p)end
end
local moved={}
for i,p in ipairs(others)do
if bring(p,owner,(i/#others)*math.pi*2)then table.insert(moved,p)end
end
return moved
end
local function handleChat(player,message)
local prefix=CONFIG.Prefix
if string.sub(message,1,#prefix)~=prefix then return end
if not isOwner(player)then return end
local args=string.split(string.sub(message,#prefix+1)," ")
local cmd=string.lower(table.remove(args,1)or "")
local query=args[1]
if cmd=="give" or cmd=="panel" or cmd=="add" then
local targets=findPlayers(query or "me",player)
if#targets==0 then
notifyClient(player,"HYPERD","No player matches \"" .. tostring(query).. "\".","bad")
return
end
local given={}
for _,p in ipairs(targets)do
if grant(p,player)then table.insert(given,p)end
end
notifyClient(player,"Panel given",nameList(given),"good")
elseif cmd=="remove" or cmd=="take" or cmd=="revoke" then
if not query then
notifyClient(player,"HYPERD","Usage: " .. prefix .. "remove <name | all>","bad")
return
end
local targets=findPlayers(query,player)
if#targets==0 then
notifyClient(player,"HYPERD","No player matches \"" .. query .. "\".","bad")
return
end
local removed={}
for _,p in ipairs(targets)do
if revoke(p)then table.insert(removed,p)end
end
notifyClient(player,"Panel removed",nameList(removed),"bad")
elseif cmd=="bring" or cmd=="tp" then
if not query then
notifyClient(player,"HYPERD","Usage: " .. prefix .. "bring <name | all | others>","bad")
return
end
local targets=findPlayers(query,player)
if#targets==0 then
notifyClient(player,"HYPERD","No player matches \"" .. query .. "\".","bad")
return
end
local moved
if#targets==1 then
moved=bring(targets[1],player)and{targets[1]}or{}
else
moved=bringMany(targets,player)
end
notifyClient(player,"Brought",nameList(moved),#moved>0 and "good" or "bad")
elseif cmd=="list" then
local holders={}
for _,p in ipairs(Players:GetPlayers())do
if hasAccess(p)then table.insert(holders,p)end
end
notifyClient(player,"Panel holders",nameList(holders),"info")
elseif cmd=="help" then
notifyClient(player,"HYPERD commands",
prefix .. "give <name|me|all|others>   " .. prefix .. "remove <name|all>   " .. prefix .. "bring <name|all>   " .. prefix .. "list","info")
end
end
local pinAttempts,vipLast={},{}
local function handleVip(player,action,arg)
if not hasAccess(player)then return end
local now=os.clock()
if action=="vipPin" then
if typeof(arg)~="string" then return end
local st=pinAttempts[player]
if not st then
st={fails=0,lockedUntil=0,last=0}
pinAttempts[player]=st
end
if now - st.last<0.4 then return end
st.last=now
if now<st.lockedUntil then
remote:FireClient(player,"vipResult",false,"LOCKED " .. math.ceil(st.lockedUntil - now).. "s")
return
end
if arg==CONFIG.VipPin then
st.fails=0
player:SetAttribute("HyperdVIP",true)
remote:FireClient(player,"vipResult",true,"OK")
else
st.fails+=1
if st.fails>=CONFIG.VipMaxAttempts then
st.fails=0
st.lockedUntil=now+CONFIG.VipLockSeconds
remote:FireClient(player,"vipResult",false,"LOCKED " .. CONFIG.VipLockSeconds .. "s")
else
remote:FireClient(player,"vipResult",false,(CONFIG.VipMaxAttempts - st.fails).. " ATTEMPTS LEFT")
end
end
return
end
if action=="wallShot" and typeof(arg)=="number" and CONFIG.AllowWallShot then
local last=vipLast[player]or{}
vipLast[player]=last
if now -(last.shot or 0)<CONFIG.WallShotCooldown then return end
last.shot=now
local target=Players:GetPlayerByUserId(arg)
if not target or target==player then return end
if CONFIG.WallShotIgnoreTeam and player.Team and target.Team==player.Team then return end
local sRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local tChar=target.Character
local tHead=tChar and(tChar:FindFirstChild("Head")or tChar:FindFirstChild("HumanoidRootPart"))
local hum=tChar and tChar:FindFirstChildOfClass("Humanoid")
if not sRoot or not tHead or not hum or hum.Health<=0 then return end
if(tHead.Position - sRoot.Position).Magnitude>CONFIG.WallShotRange then return end
hum:TakeDamage(CONFIG.WallShotDamage)
remote:FireClient(player,"shotFx",sRoot.Position+Vector3.new(0,1.5,0),tHead.Position)
elseif action=="vipHeal" then
local last=vipLast[player]or{}
vipLast[player]=last
if now -(last.heal or -1e9)<CONFIG.VipHealCooldown then
notifyClient(player,"Server heal","On cooldown.","bad")
return
end
local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if hum and hum.Health>0 then
last.heal=now
hum.Health=hum.MaxHealth
notifyClient(player,"Server heal","Health restored.","good")
end
end
end
local Debris=game:GetService("Debris")
local toolCfg,toolAim,toolLast,ownedTools,keepFlag={},{},{},{},{}
local frozen,ragId={},{}
local serverLocked=false
local TOOL_ORDER={"Bat","Fling Launcher","Freeze Ray","Teleport Wand","Speed Coil","Gravity Coil","Heal Wand"}
local TOOL_DEFS={
["Bat"]={tip="Swing at players to knock them back and ragdoll them",color=Color3.fromRGB(150,100,55),
size=Vector3.new(0.8,0.8,4.2),grip=CFrame.new(0,0,-1.4),mat=Enum.Material.Wood},
["Fling Launcher"]={tip="Launches the nearest player (or your target) far away",color=Color3.fromRGB(255,80,80),
size=Vector3.new(1,1.2,2.6),grip=CFrame.new(0,0,-0.6),mat=Enum.Material.Metal},
["Freeze Ray"]={tip="Freezes a player in place for a few seconds",color=Color3.fromRGB(110,200,255),
size=Vector3.new(0.9,0.9,2.4),grip=CFrame.new(0,0,-0.6),mat=Enum.Material.Glass},
["Teleport Wand"]={tip="Click anywhere to teleport there (aiming needs the HYPERD panel)",color=Color3.fromRGB(170,120,255),
size=Vector3.new(0.6,0.6,3.4),grip=CFrame.new(0,0,-1.2),mat=Enum.Material.Neon},
["Speed Coil"]={tip="Run faster while equipped",color=Color3.fromRGB(255,200,60),
size=Vector3.new(1.6,1.6,1.6),grip=CFrame.new(),mat=Enum.Material.Neon},
["Gravity Coil"]={tip="Jump much higher while equipped",color=Color3.fromRGB(80,160,255),
size=Vector3.new(1.6,1.6,1.6),grip=CFrame.new(),mat=Enum.Material.Neon},
["Heal Wand"]={tip="Heals you and nearby players",color=Color3.fromRGB(80,255,140),
size=Vector3.new(0.6,0.6,3),grip=CFrame.new(0,0,-1),mat=Enum.Material.Neon},
}
local function cfgFor(player)
local c=toolCfg[player]
if not c then
c={kb=CONFIG.BatKnockback,rag=CONFIG.RagdollTime,fling=CONFIG.FlingPower,
range=CONFIG.FlingRange,freeze=CONFIG.FreezeTime}
toolCfg[player]=c
end
return c
end
local function canUseTools(player)
return hasAccess(player)and(isOwner(player)or not CONFIG.ToolsOwnersOnly)
end
local function charParts(player)
local ch=player.Character
local hum=ch and ch:FindFirstChildOfClass("Humanoid")
local root=ch and ch:FindFirstChild("HumanoidRootPart")
if hum and root and hum.Health>0 then
return ch,hum,root
end
return nil
end
local function isProtected(target,by)
if target==by then return true end
if CONFIG.ToolsProtectOwners and isOwner(target)then return true end
local ch=target.Character
if CONFIG.ToolsProtectForceField and ch and ch:FindFirstChildOfClass("ForceField")then return true end
return false
end
local function ragdoll(target,seconds)
local ch,hum=charParts(target)
if not ch then return end
ragId[target]=(ragId[target]or 0)+1
local id=ragId[target]
hum.PlatformStand=true
pcall(function()hum:ChangeState(Enum.HumanoidStateType.Ragdoll)end)
task.delay(seconds,function()
if ragId[target]==id and hum.Parent and hum.Health>0 then
hum.PlatformStand=false
pcall(function()hum:ChangeState(Enum.HumanoidStateType.GettingUp)end)
end
end)
end
local function launch(target,velocity,spin)
local ch,hum,root=charParts(target)
if not ch then return end
local att=Instance.new("Attachment")
att.Name="HyperdLaunchAtt"
att.Parent=root
local lv=Instance.new("LinearVelocity")
lv.Name="HyperdLaunch"
lv.Attachment0=att
lv.MaxForce=math.huge
lv.RelativeTo=Enum.ActuatorRelativeTo.World
lv.VectorVelocity=velocity
lv.Parent=root
Debris:AddItem(lv,0.28)
if spin then
local av=Instance.new("AngularVelocity")
av.Name="HyperdSpin"
av.Attachment0=att
av.MaxTorque=math.huge
av.RelativeTo=Enum.ActuatorRelativeTo.World
av.AngularVelocity=Vector3.new(math.random(-12,12),math.random(-12,12),math.random(-12,12))
av.Parent=root
Debris:AddItem(av,0.6)
end
Debris:AddItem(att,0.7)
end
local function thawPlayer(target)
frozen[target]=(frozen[target]or 0)+1
local ch=target.Character
local root=ch and ch:FindFirstChild("HumanoidRootPart")
if root then root.Anchored=false end
local hl=ch and ch:FindFirstChild("HyperdFreeze")
if hl then hl:Destroy()end
end
local function freezePlayer(target,seconds)
local ch,hum,root=charParts(target)
if not ch then return end
thawPlayer(target)
frozen[target]=(frozen[target]or 0)+1
local id=frozen[target]
root.Anchored=true
local hl=Instance.new("Highlight")
hl.Name="HyperdFreeze"
hl.FillColor=Color3.fromRGB(110,200,255)
hl.OutlineColor=Color3.new(1,1,1)
hl.FillTransparency=0.35
hl.Parent=ch
if seconds then
task.delay(seconds,function()
if frozen[target]==id then thawPlayer(target)end
end)
end
end
local function aimedTarget(player,root,range)
local aim=toolAim[player]
if aim and aim.userId and os.clock()- aim.t<1.5 then
local p=Players:GetPlayerByUserId(aim.userId)
if p then
local ch,hum,r2=charParts(p)
if ch and(r2.Position - root.Position).Magnitude<=range then return p,r2 end
end
end
local front,fd,any,ad
for _,p in ipairs(Players:GetPlayers())do
if p~=player then
local ch,hum,r2=charParts(p)
if ch then
local off=r2.Position - root.Position
local d=off.Magnitude
if d<=range and d>0.1 then
if root.CFrame.LookVector:Dot(off.Unit)>0.3 and(not fd or d<fd)then front,fd=p,d end
if not ad or d<ad then any,ad=p,d end
end
end
end
end
local pick=front or any
if pick then
local _,_,r2=charParts(pick)
return pick,r2
end
return nil
end
local function flatDir(from,to,fallback)
local off=to - from
local d=Vector3.new(off.X,0,off.Z)
if d.Magnitude>0.1 then return d.Unit end
return fallback
end
local TOOL_USE={}
TOOL_USE["Bat"]=function(player,tool,ch,hum,root,cfg)
local sw=Instance.new("StringValue")
sw.Name="toolanim"
sw.Value="Slash"
sw.Parent=tool
Debris:AddItem(sw,0.2)
for _,p in ipairs(Players:GetPlayers())do
if not isProtected(p,player)then
local pch,phum,proot=charParts(p)
if pch then
local off=proot.Position - root.Position
if off.Magnitude<=CONFIG.BatRange and off.Magnitude>0.1
and root.CFrame.LookVector:Dot(off.Unit)>0.2 then
local dir=flatDir(root.Position,proot.Position,root.CFrame.LookVector)
launch(p,(dir+Vector3.new(0,0.45,0)).Unit*cfg.kb,true)
ragdoll(p,cfg.rag)
if CONFIG.BatDamage>0 then phum:TakeDamage(CONFIG.BatDamage)end
end
end
end
end
end
TOOL_USE["Fling Launcher"]=function(player,tool,ch,hum,root,cfg)
local p,proot=aimedTarget(player,root,cfg.range)
if not p or isProtected(p,player)then return end
local dir=flatDir(root.Position,proot.Position,root.CFrame.LookVector)
launch(p,(dir+Vector3.new(0,0.6,0)).Unit*cfg.fling,true)
ragdoll(p,4)
remote:FireClient(player,"shotFx",root.Position+Vector3.new(0,1.5,0),proot.Position)
end
TOOL_USE["Freeze Ray"]=function(player,tool,ch,hum,root,cfg)
local p,proot=aimedTarget(player,root,120)
if not p or isProtected(p,player)then return end
freezePlayer(p,cfg.freeze)
remote:FireClient(player,"shotFx",root.Position+Vector3.new(0,1.5,0),proot.Position)
end
TOOL_USE["Teleport Wand"]=function(player,tool,ch,hum,root)
local aim=toolAim[player]
if not aim or not aim.pos or os.clock()- aim.t>1.5 then return end
if(aim.pos - root.Position).Magnitude>600 then return end
local to=aim.pos+Vector3.new(0,3.5,0)
root.CFrame=CFrame.new(to,to+root.CFrame.LookVector)
end
TOOL_USE["Heal Wand"]=function(player,tool,ch,hum,root)
for _,p in ipairs(Players:GetPlayers())do
local pch,phum,proot=charParts(p)
if pch and(p==player or(proot.Position - root.Position).Magnitude<=20)then
phum.Health=math.min(phum.MaxHealth,phum.Health+CONFIG.HealWandAmount)
end
end
end
local function newTool(name)
local def=TOOL_DEFS[name]
local tool=Instance.new("Tool")
tool.Name=name
tool.ToolTip=def.tip
tool.CanBeDropped=false
tool.RequiresHandle=true
tool.Grip=def.grip
tool:SetAttribute("HyperdTool",name)
local handle=Instance.new("Part")
handle.Name="Handle"
handle.Size=def.size
handle.Color=def.color
handle.Material=def.mat
handle.CanCollide=false
handle.Massless=true
handle.Parent=tool
return tool
end
local function setupTool(player,tool,name)
if name=="Speed Coil" or name=="Gravity Coil" then
local savedHum,saved
tool.Equipped:Connect(function()
local h=tool.Parent and tool.Parent:FindFirstChildOfClass("Humanoid")
if not h then return end
savedHum=h
if name=="Speed Coil" then
saved=h.WalkSpeed
h.WalkSpeed=saved*1.8
else
h.UseJumpPower=true
saved=h.JumpPower
h.JumpPower=saved*1.9
end
end)
tool.Unequipped:Connect(function()
if savedHum and savedHum.Parent and saved then
if name=="Speed Coil" then
savedHum.WalkSpeed=saved
else
savedHum.JumpPower=saved
end
end
savedHum,saved=nil,nil
end)
return
end
local use=TOOL_USE[name]
tool.Activated:Connect(function()
local now=os.clock()
if now -(toolLast[player]or 0)<CONFIG.ToolCooldown then return end
local ch,hum,root=charParts(player)
if not ch or tool.Parent~=ch then return end
toolLast[player]=now
use(player,tool,ch,hum,root,cfgFor(player))
end)
end
local function hasTool(player,name)
for _,container in ipairs({player:FindFirstChildOfClass("Backpack"),player.Character})do
if container then
for _,t in ipairs(container:GetChildren())do
if t:IsA("Tool")and t:GetAttribute("HyperdTool")==name then return true end
end
end
end
return false
end
local function giveTool(player,name)
if not TOOL_DEFS[name]then return false end
local pack=player:FindFirstChildOfClass("Backpack")
if not pack then return false end
ownedTools[player]=ownedTools[player]or{}
ownedTools[player][name]=true
if hasTool(player,name)then return true end
local tool=newTool(name)
setupTool(player,tool,name)
tool.Parent=pack
return true
end
local function removeTools(player,name)
local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if hum then hum:UnequipTools()end
for _,container in ipairs({player:FindFirstChildOfClass("Backpack"),player.Character})do
if container then
for _,t in ipairs(container:GetChildren())do
local tn=t:IsA("Tool")and t:GetAttribute("HyperdTool")
if tn and(name==nil or tn==name)then t:Destroy()end
end
end
end
if ownedTools[player]then
if name==nil then ownedTools[player]={}else ownedTools[player][name]=nil end
end
end
local function hookTools(player)
player.CharacterAdded:Connect(function()
local set=ownedTools[player]
if not set then return end
if keepFlag[player]==false or(keepFlag[player]==nil and not CONFIG.KeepToolsOnRespawn)then
ownedTools[player]={}
return
end
task.wait(0.4)
if not player:WaitForChild("Backpack",5)then return end
for name in pairs(set)do giveTool(player,name)end
end)
end
local function cleanupTools(player)
toolCfg[player],toolAim[player],toolLast[player]=nil,nil,nil
ownedTools[player],keepFlag[player],frozen[player],ragId[player]=nil,nil,nil,nil
end
task.spawn(function()
while true do
task.wait(0.5)
for _,p in ipairs(Players:GetPlayers())do
local rate=p:GetAttribute("HyperdRegen")
if typeof(rate)=="number" and rate>0 then
local ch,hum=charParts(p)
if ch and hum.Health<hum.MaxHealth then
hum.Health=math.min(hum.MaxHealth,hum.Health+rate*0.5)
end
end
end
end
end)
local toolCmdLast={}
local function handleTools(player,action,arg,extra)
if not hasAccess(player)then return end
if action=="toolAim" then
local pos=(typeof(extra)=="Vector3" and extra.Magnitude<1e6)and extra or nil
local uid=typeof(arg)=="number" and arg or nil
toolAim[player]={userId=uid,pos=pos,t=os.clock()}
return
end
if action=="regen" then
if typeof(arg)=="number" and arg==arg then
player:SetAttribute("HyperdRegen",math.clamp(arg,0,CONFIG.RegenMax))
end
return
end
if not canUseTools(player)then
notifyClient(player,"Tools","Only owners can use tools on this server.","bad")
return
end
local now=os.clock()
if now -(toolCmdLast[player]or 0)<0.15 then return end
toolCmdLast[player]=now
if action=="toolGive" or action=="toolTake" then
if typeof(arg)~="string" then return end
local target=player
if typeof(extra)=="number" and extra~=player.UserId then
if not isOwner(player)then return end
target=Players:GetPlayerByUserId(extra)
if not target then return end
end
if action=="toolGive" then
if arg=="ALL" then
for _,n in ipairs(TOOL_ORDER)do giveTool(target,n)end
notifyClient(player,"Tools","Gave all tools to " .. target.DisplayName,"good")
elseif giveTool(target,arg)then
notifyClient(player,"Tools",arg .. " → " .. target.DisplayName,"good")
end
if target~=player then
notifyClient(target,"HYPERD",player.DisplayName .. " gave you " ..(arg=="ALL" and "some tools" or arg).. ".","info")
end
else
removeTools(target,arg~="ALL" and arg or nil)
notifyClient(player,"Tools","Removed from " .. target.DisplayName,"bad")
end
elseif action=="toolCfg" and typeof(arg)=="string" and typeof(extra)=="number" and extra==extra then
local c=cfgFor(player)
if arg=="kb" then
c.kb=math.clamp(extra,10,CONFIG.BatKnockbackMax)
elseif arg=="rag" then
c.rag=math.clamp(extra,0.5,CONFIG.RagdollTimeMax)
elseif arg=="fling" then
c.fling=math.clamp(extra,40,CONFIG.FlingPowerMax)
elseif arg=="range" then
c.range=math.clamp(extra,10,CONFIG.FlingRangeMax)
elseif arg=="freeze" then
c.freeze=math.clamp(extra,1,CONFIG.FreezeTimeMax)
end
elseif action=="toolKeep" and typeof(arg)=="boolean" then
keepFlag[player]=arg
end
end
local lastCall={}
remote.OnServerEvent:Connect(function(player,action,arg,extra)
if typeof(action)~="string" then return end
if action=="vipPin" or action=="wallShot" or action=="vipHeal" then
handleVip(player,action,arg)
return
end
if action=="toolGive" or action=="toolTake" or action=="toolCfg" or action=="toolAim"
or action=="toolKeep" or action=="regen" then
handleTools(player,action,arg,extra)
return
end
if not isOwner(player)then return end
local now=os.clock()
if(lastCall[player]or 0)+0.2>now then return end
lastCall[player]=now
if action=="grant" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
if target and grant(target,player)then
notifyClient(player,"Panel given",target.DisplayName,"good")
end
elseif action=="revoke" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
if target and revoke(target)then
notifyClient(player,"Panel removed",target.DisplayName,"bad")
end
elseif action=="bring" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
if target and bring(target,player)then
notifyClient(player,"Brought",target.DisplayName,"good")
else
notifyClient(player,"HYPERD","Couldn't bring that player (no character).","bad")
end
elseif action=="bringAll" then
local moved=bringMany(Players:GetPlayers(),player)
notifyClient(player,"Brought",nameList(moved),#moved>0 and "good" or "bad")
elseif action=="announce" and typeof(arg)=="string" then
local msg=string.sub(arg,1,200)
for _,p in ipairs(Players:GetPlayers())do
if hasAccess(p)then notifyClient(p,"ANNOUNCEMENT",msg,"info")end
end
elseif action=="kick" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
if target and target~=player and not isOwner(target)then
notifyClient(player,"Kicked",target.DisplayName,"bad")
target:Kick("You were removed from the server by an admin.")
else
notifyClient(player,"Kick","That player can't be kicked.","bad")
end
elseif action=="kickAll" then
local n=0
for _,p in ipairs(Players:GetPlayers())do
if p~=player and not isOwner(p)then
p:Kick("The server was closed by an admin.")
n+=1
end
end
notifyClient(player,"Kicked",n .. " player(s)","bad")
elseif action=="freeze" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
if target and not isOwner(target)then
freezePlayer(target,nil)
notifyClient(player,"Frozen",target.DisplayName,"good")
end
elseif action=="unfreeze" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
if target then
thawPlayer(target)
notifyClient(player,"Unfrozen",target.DisplayName,"good")
end
elseif action=="healPlayer" and typeof(arg)=="number" then
local target=Players:GetPlayerByUserId(arg)
local ch,hum=nil,nil
if target then ch,hum=charParts(target)end
if hum then
hum.Health=hum.MaxHealth
notifyClient(player,"Healed",target.DisplayName,"good")
end
elseif action=="lockServer" and typeof(arg)=="boolean" then
serverLocked=arg
notifyClient(player,"Server lock",arg and "Locked: new players are kicked." or "Unlocked.",arg and "bad" or "good")
elseif action=="grantAll" then
local given={}
for _,p in ipairs(Players:GetPlayers())do
if not hasAccess(p)and grant(p,player)then table.insert(given,p)end
end
notifyClient(player,"Panel given",nameList(given),"good")
elseif action=="revokeAll" then
local removed={}
for _,p in ipairs(Players:GetPlayers())do
if hasAccess(p)and revoke(p)then table.insert(removed,p)end
end
notifyClient(player,"Panel removed",nameList(removed),"bad")
end
end)
local function onPlayer(player)
local owner=isOwner(player)
if serverLocked and not owner then
player:Kick("This server is locked by an admin.")
return
end
player:SetAttribute("HyperdOwner",owner)
player.Chatted:Connect(function(message)handleChat(player,message)end)
hookTools(player)
local should=owner and CONFIG.OwnersAlwaysHavePanel
if not should and store then
local ok,data=pcall(function()return store:GetAsync(tostring(player.UserId))end)
should=ok and data==true
end
if should and player.Parent then
grant(player)
end
end
Players.PlayerAdded:Connect(function(player)task.spawn(onPlayer,player)end)
for _,player in ipairs(Players:GetPlayers())do task.spawn(onPlayer,player)end
Players.PlayerRemoving:Connect(function(player)
lastCall[player]=nil
pinAttempts[player]=nil
vipLast[player]=nil
cleanupTools(player)
groupCache[player.UserId]=nil
end)
print("[HYPERD] server ready.")
return
end
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local TeleportService=game:GetService("TeleportService")
local Stats=game:GetService("Stats")
local LP=Players.LocalPlayer
local PG=LP:WaitForChild("PlayerGui")
local DELIVERED=script:GetAttribute("Delivered")==true
local REMOTE=nil
local IS_OWNER=false
if DELIVERED then
local waited=os.clock()
while LP:GetAttribute("HyperdAccess")==nil and os.clock()- waited<5 do task.wait()end
if LP:GetAttribute("HyperdAccess")~=true then
script:Destroy()
return
end
REMOTE=game:GetService("ReplicatedStorage"):WaitForChild("HyperdRemote",10)
IS_OWNER=LP:GetAttribute("HyperdOwner")==true and REMOTE~=nil
end
local CONFIG={
ToggleKey=Enum.KeyCode.RightShift,
LoadingEveryOpen=false,
ExplorerOwnersOnly=true,
CutsceneEveryTime=true,
CustomDances={
},
}
for _,n in ipairs({"HyperdGui","HyperdHud"})do
local o=PG:FindFirstChild(n)
if o then o:Destroy()end
end
pcall(function()RunService:UnbindFromRenderStep("HyperdAim")end)
local CAN_EXPLORE=(not DELIVERED)or IS_OWNER or(not CONFIG.ExplorerOwnersOnly)
local WHITE=Color3.new(1,1,1)
local PALETTES={
{name="Hyper Violet",a=Color3.fromRGB(150,90,255),b=Color3.fromRGB(0,215,255)},
{name="Neon Rose",a=Color3.fromRGB(255,70,160),b=Color3.fromRGB(255,170,70)},
{name="Toxic",a=Color3.fromRGB(70,255,140),b=Color3.fromRGB(0,200,255)},
{name="Inferno",a=Color3.fromRGB(255,60,70),b=Color3.fromRGB(255,170,40)},
{name="Arctic",a=Color3.fromRGB(120,190,255),b=Color3.fromRGB(190,150,255)},
}
local C={
A=PALETTES[1].a,
B=PALETTES[1].b,
BG=Color3.fromRGB(11,11,20),
Side=Color3.fromRGB(8,8,15),
Panel=Color3.fromRGB(19,19,33),
Panel2=Color3.fromRGB(28,28,47),
Hover=Color3.fromRGB(40,40,68),
Off=Color3.fromRGB(48,48,74),
Line=Color3.fromRGB(58,58,92),
Text=Color3.fromRGB(240,242,255),
Muted=Color3.fromRGB(142,148,180),
Green=Color3.fromRGB(70,255,140),
Red=Color3.fromRGB(255,75,95),
Yellow=Color3.fromRGB(255,205,70),
}
local accentFns={}
local function onAccent(fn)
table.insert(accentFns,fn)
fn()
end
local function applyPalette(index)
local p=PALETTES[index]
C.A,C.B=p.a,p.b
for _,fn in ipairs(accentFns)do
local ok,err=pcall(fn)
if not ok then warn("[HYPERD] theme: " .. tostring(err))end
end
end
local original={
brightness=Lighting.Brightness,
fov=(workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView)or 70,
walkSpeed=16,
jumpPower=50,
clock=Lighting.ClockTime,
gravity=workspace.Gravity,
zoom=LP.CameraMaxZoomDistance,
ambient=Lighting.Ambient,
outdoor=Lighting.OutdoorAmbient,
shadows=Lighting.GlobalShadows,
}
do
local ch=LP.Character
local h=ch and ch:FindFirstChildOfClass("Humanoid")
if h then
original.walkSpeed=math.floor(h.WalkSpeed+0.5)
original.jumpPower=math.floor(h.JumpPower+0.5)
end
end
local defaultFlags={
Fly=false,InfJump=false,
ESPOutline=false,ESPNames=false,ESPDistance=false,ESPHealth=false,TeamCheck=false,
AutoHeal=false,HighJump=false,Sprint=false,
Glow=false,Trail=false,Blur=false,
Aimbot=false,AimShowFOV=true,AimFill=false,AimSticky=true,
AimWall=false,AimTeam=true,AimMarker=true,AimFollowCursor=true,
Noclip=false,ClickTP=false,Rainbow=false,Aura=false,Bloom=false,
Fullbright=false,FPSBoost=false,Crosshair=false,AntiAFK=false,
ESPTracers=false,OrbitCam=false,Particles=true,
RainbowUI=false,MouseGlow=true,
VipAimbot=false,VipWalls=true,VipWallShot=false,VipInfo=true,VipRadar=false,VipBlink=false,
}
local flags={}
for k,v in pairs(defaultFlags)do flags[k]=v end
local AIM_DEFAULT={fov=150,strength=45,thick=2}
local aim={fov=AIM_DEFAULT.fov,strength=AIM_DEFAULT.strength,thick=AIM_DEFAULT.thick,color=nil}
local vip={fov=260,smooth=65,predict=60,speed=900,range=700,priority=1,blink=35}
local AIM_PARTS={"Head","Chest","Root"}
local aimPartIndex=1
local speeds={walk=original.walkSpeed,jump=original.jumpPower,sprint=26,fly=70}
local esp={fill=C.A,outline=WHITE}
local highlights,labels,trailParts={},{},{}
local S={
selected=nil,locked=nil,activeAnim=nil,
flyConn=nil,healConn=nil,glow=nil,blur=nil,
loading=false,minimized=false,open=false,firstOpen=true,
spectating=false,page=nil,sprinting=false,
animSpeed=1,rebinding=false,
}
local ui={}
local sliders={}
local resetAll
local selectPage
local conns={}
local function connect(signal,fn)
local c=signal:Connect(fn)
table.insert(conns,c)
return c
end
local function new(class,props,parent)
local o=Instance.new(class)
if props then
for k,v in pairs(props)do o[k]=v end
end
if parent then o.Parent=parent end
return o
end
local function tween(o,t,props,style,dir)
local tw=TweenService:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),props)
tw:Play()
return tw
end
local function corner(o,r)
return new("UICorner",{CornerRadius=UDim.new(0,r or 10)},o)
end
local function stroke(o,color,thickness,transparency)
return new("UIStroke",{
Color=color or C.Line,
Thickness=thickness or 1,
Transparency=transparency or 0,
ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
},o)
end
local function accentGradient(parent,rotation,reversed)
local g=new("UIGradient",{Rotation=rotation or 0},parent)
onAccent(function()
g.Color=reversed and ColorSequence.new(C.B,C.A)or ColorSequence.new(C.A,C.B)
end)
return g
end
local function label(parent,text,size,pos,textSize,color,font)
return new("TextLabel",{
BackgroundTransparency=1,
Size=size,
Position=pos or UDim2.new(),
Text=text,
TextColor3=color or C.Text,
Font=font or Enum.Font.GothamMedium,
TextSize=textSize or 13,
TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Center,
TextWrapped=true,
},parent)
end
local function center(l)
l.TextXAlignment=Enum.TextXAlignment.Center
return l
end
local function button(parent,text,size,pos,primary)
local b=new("TextButton",{
Size=size,
Position=pos or UDim2.new(),
BackgroundColor3=primary and WHITE or C.Panel2,
Text=text,
TextColor3=C.Text,
Font=Enum.Font.GothamBold,
TextSize=12,
AutoButtonColor=false,
},parent)
corner(b,9)
local st
if primary then
accentGradient(b,20)
else
st=stroke(b,C.Line,1,0.3)
end
b.ClipsDescendants=true
b.MouseButton1Down:Connect(function()
local panel=b:FindFirstAncestor("HyperdPanel")
local us=panel and panel:FindFirstChildOfClass("UIScale")
local sc=us and us.Scale or 1
local m=UIS:GetMouseLocation()
local px=(m.X - b.AbsolutePosition.X)/sc
local py=(m.Y - b.AbsolutePosition.Y)/sc
local rip=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(px,py),
Size=UDim2.fromOffset(0,0),BackgroundColor3=WHITE,BackgroundTransparency=0.65,
BorderSizePixel=0,
},b)
corner(rip,1000)
local d=math.max(b.AbsoluteSize.X,b.AbsoluteSize.Y)/sc*2.4
tween(rip,0.45,{Size=UDim2.fromOffset(d,d),BackgroundTransparency=1})
task.delay(0.5,function()if rip.Parent then rip:Destroy()end end)
end)
b.MouseEnter:Connect(function()
tween(b,0.12,{BackgroundColor3=primary and Color3.fromRGB(205,205,230)or C.Hover})
if st then tween(st,0.12,{Color=C.A,Transparency=0})end
end)
b.MouseLeave:Connect(function()
tween(b,0.12,{BackgroundColor3=primary and WHITE or C.Panel2})
if st then tween(st,0.12,{Color=C.Line,Transparency=0.3})end
end)
return b,st
end
local function character()return LP.Character end
local function humanoid()
local ch=LP.Character
return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function rootPart()
local ch=LP.Character
return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function cam()return workspace.CurrentCamera end
local function fmtTime(s)
s=math.floor(s)
return string.format("%d:%02d:%02d",s//3600,(s%3600)//60,s%60)
end
local function makeDraggable(handle,target,onTap)
local dragging,moved=false,false
local startMouse,startPos
handle.InputBegan:Connect(function(input)
if input.UserInputType==Enum.UserInputType.MouseButton1
or input.UserInputType==Enum.UserInputType.Touch then
dragging,moved=true,false
startMouse=input.Position
startPos=target.Position
end
end)
connect(UIS.InputChanged,function(input)
if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement
or input.UserInputType==Enum.UserInputType.Touch)then
local d=input.Position - startMouse
if d.Magnitude>4 then moved=true end
if moved then
target.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
startPos.Y.Scale,startPos.Y.Offset+d.Y)
end
end
end)
connect(UIS.InputEnded,function(input)
if dragging and(input.UserInputType==Enum.UserInputType.MouseButton1
or input.UserInputType==Enum.UserInputType.Touch)then
dragging=false
if not moved and onTap then onTap()end
end
end)
end
local gui=new("ScreenGui",{
Name="HyperdGui",ResetOnSpawn=false,IgnoreGuiInset=true,
DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},PG)
local hud=new("ScreenGui",{
Name="HyperdHud",ResetOnSpawn=false,IgnoreGuiInset=true,
DisplayOrder=50,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},PG)
local notifHolder=new("Frame",{
BackgroundTransparency=1,AnchorPoint=Vector2.new(1,1),
Position=UDim2.new(1,-18,1,-18),Size=UDim2.new(0,300,1,-36),
},gui)
new("UIListLayout",{
SortOrder=Enum.SortOrder.LayoutOrder,
VerticalAlignment=Enum.VerticalAlignment.Bottom,
HorizontalAlignment=Enum.HorizontalAlignment.Right,
Padding=UDim.new(0,8),
},notifHolder)
local notifCount=0
local function notify(title,message,color)
color=color or C.A
notifCount+=1
local wrap=new("Frame",{
BackgroundTransparency=1,Size=UDim2.new(0,280,0,62),LayoutOrder=notifCount,
},notifHolder)
local f=new("Frame",{
BackgroundColor3=C.Panel,Position=UDim2.new(0,310,0,0),Size=UDim2.fromScale(1,1),
},wrap)
corner(f,12)
stroke(f,color,1.2,0.4)
local accent=new("Frame",{
BackgroundColor3=color,Position=UDim2.new(0,8,0,9),Size=UDim2.new(0,4,1,-20),
},f)
corner(accent,2)
label(f,title,UDim2.new(1,-34,0,20),UDim2.new(0,22,0,8),13,color,Enum.Font.GothamBold)
local msg=label(f,message,UDim2.new(1,-34,0,22),UDim2.new(0,22,0,28),11,C.Muted)
msg.TextYAlignment=Enum.TextYAlignment.Top
local prog=new("Frame",{
BackgroundColor3=color,BackgroundTransparency=0.35,
Position=UDim2.new(0,10,1,-5),Size=UDim2.new(1,-20,0,2),
},f)
corner(prog,1)
tween(f,0.32,{Position=UDim2.new()},Enum.EasingStyle.Back)
tween(prog,2.8,{Size=UDim2.new(0,0,0,2)},Enum.EasingStyle.Linear)
task.delay(3,function()
if f.Parent then
tween(f,0.25,{Position=UDim2.new(0,310,0,0)})
task.wait(0.27)
end
if wrap.Parent then wrap:Destroy()end
end)
end
local fovCircle=new("Frame",{
Name="FOVCircle",AnchorPoint=Vector2.new(0.5,0.5),
BackgroundColor3=WHITE,BackgroundTransparency=1,
Size=UDim2.fromOffset(aim.fov*2,aim.fov*2),
Position=UDim2.fromScale(0.5,0.5),Visible=false,
},hud)
corner(fovCircle,1000)
local fovFrameGrad=new("UIGradient",{Rotation=45},fovCircle)
local fovStroke=stroke(fovCircle,WHITE,aim.thick,0.1)
local fovStrokeGrad=new("UIGradient",{},fovStroke)
local function applyFovColor()
local seq
if aim.color then
seq=ColorSequence.new(aim.color)
else
seq=ColorSequence.new({
ColorSequenceKeypoint.new(0,C.A),
ColorSequenceKeypoint.new(0.5,C.B),
ColorSequenceKeypoint.new(1,C.A),
})
end
fovFrameGrad.Color=seq
fovStrokeGrad.Color=seq
end
onAccent(applyFovColor)
local marker=new("Frame",{
Name="AimMarker",AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,
Size=UDim2.fromOffset(22,22),Visible=false,
},hud)
corner(marker,1000)
local markerStroke=stroke(marker,WHITE,2,0)
local markerGrad=new("UIGradient",{},markerStroke)
onAccent(function()markerGrad.Color=ColorSequence.new(C.A,C.B)end)
local markerDot=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=UDim2.fromOffset(4,4),BackgroundColor3=WHITE,
},marker)
corner(markerDot,4)
local crosshair=new("Frame",{
Name="Crosshair",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(0,0),Visible=false,
},hud)
local xhair={len=8,gap=4}
local xhairParts={}
for i=1,4 do
xhairParts[i]=new("Frame",{
BackgroundColor3=WHITE,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),
},crosshair)
end
local xhairDot=new("Frame",{
BackgroundColor3=WHITE,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),
Size=UDim2.fromOffset(3,3),
},crosshair)
corner(xhairDot,2)
local function layoutCrosshair()
local l,g=xhair.len,xhair.gap
xhairParts[1].Size=UDim2.fromOffset(2,l);xhairParts[1].Position=UDim2.fromOffset(0,-(g+l/2))
xhairParts[2].Size=UDim2.fromOffset(2,l);xhairParts[2].Position=UDim2.fromOffset(0,g+l/2)
xhairParts[3].Size=UDim2.fromOffset(l,2);xhairParts[3].Position=UDim2.fromOffset(-(g+l/2),0)
xhairParts[4].Size=UDim2.fromOffset(l,2);xhairParts[4].Position=UDim2.fromOffset(g+l/2,0)
end
layoutCrosshair()
onAccent(function()
for _,p in ipairs(xhairParts)do p.BackgroundColor3=C.A end
end)
local viewport=cam()and cam().ViewportSize or Vector2.new(1280,720)
local narrow=viewport.X<640
local fullSize=Vector2.new(math.clamp(viewport.X - 40,340,880),math.clamp(viewport.Y - 40,300,570))
local fullUDim=UDim2.fromOffset(fullSize.X,fullSize.Y)
local miniUDim=UDim2.fromOffset(math.min(340,fullSize.X),64)
local main=new("Frame",{
Name="HyperdPanel",AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.fromScale(0.5,0.5),Size=fullUDim,
BackgroundColor3=WHITE,ClipsDescendants=true,Visible=false,
},gui)
corner(main,18)
local uiScale=new("UIScale",{Scale=1},main)
new("UIGradient",{
Color=ColorSequence.new(Color3.fromRGB(18,14,36),Color3.fromRGB(8,9,18)),
Rotation=125,
},main)
local mainStroke=stroke(main,WHITE,2,0)
local mainStrokeGrad=new("UIGradient",{},mainStroke)
TweenService:Create(mainStroke,TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
{Thickness=3.2}):Play()
onAccent(function()
mainStrokeGrad.Color=ColorSequence.new({
ColorSequenceKeypoint.new(0,C.A),
ColorSequenceKeypoint.new(0.5,C.B),
ColorSequenceKeypoint.new(1,C.A),
})
end)
do
local orb1=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,-40,0,30),
Size=UDim2.fromOffset(340,340),BackgroundColor3=WHITE,BackgroundTransparency=0.9,
},main)
corner(orb1,1000)
onAccent(function()orb1.BackgroundColor3=C.A end)
local orb2=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,120,1,10),
Size=UDim2.fromOffset(300,300),BackgroundColor3=WHITE,BackgroundTransparency=0.92,
},main)
corner(orb2,1000)
onAccent(function()orb2.BackgroundColor3=C.B end)
end
local mouseGlow=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(280,280),
Position=UDim2.fromOffset(300,200),BackgroundColor3=WHITE,BackgroundTransparency=0.9,
BorderSizePixel=0,
},main)
corner(mouseGlow,1000)
onAccent(function()mouseGlow.BackgroundColor3=C.A end)
local particleLayer=new("Frame",{
BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ClipsDescendants=true,
},main)
local particleDots={}
for i=1,16 do
local sz=math.random(2,5)
local dot=new("Frame",{
Size=UDim2.fromOffset(sz,sz),BackgroundTransparency=1,BorderSizePixel=0,
BackgroundColor3=(i%2==0)and C.A or C.B,Position=UDim2.new(math.random(),0,1.05,0),
},particleLayer)
corner(dot,4)
particleDots[i]={dot=dot,alt=(i%2==0)}
task.spawn(function()
task.wait(math.random()*6)
while dot.Parent do
if flags.Particles and main.Visible then
local t=6+math.random()*7
local x=math.random()
dot.Position=UDim2.new(x,0,1.05,0)
dot.BackgroundTransparency=0.55
tween(dot,t,{
Position=UDim2.new(math.clamp(x+(math.random()- 0.5)*0.2,0,1),0,-0.05,0),
BackgroundTransparency=1,
},Enum.EasingStyle.Linear)
task.wait(t)
else
dot.BackgroundTransparency=1
task.wait(0.5)
end
end
end)
end
onAccent(function()
for _,d in ipairs(particleDots)do d.dot.BackgroundColor3=d.alt and C.A or C.B end
end)
local header=new("Frame",{Size=UDim2.new(1,0,0,64),BackgroundTransparency=1,Active=true},main)
new("Frame",{
BackgroundColor3=C.Line,BackgroundTransparency=0.5,
Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0,64),
},main)
local logo=new("Frame",{
Size=UDim2.fromOffset(38,38),Position=UDim2.new(0,16,0,13),BackgroundColor3=WHITE,
},header)
corner(logo,11)
accentGradient(logo,45)
stroke(logo,WHITE,1,0.7)
center(label(logo,"H",UDim2.fromScale(1,1),nil,22,WHITE,Enum.Font.GothamBlack))
logo.ClipsDescendants=true
local sheen=new("Frame",{
Size=UDim2.new(0,10,1.6,0),Position=UDim2.new(-0.5,0,-0.3,0),Rotation=20,
BackgroundColor3=WHITE,BackgroundTransparency=0.7,BorderSizePixel=0,
},logo)
task.spawn(function()
while logo.Parent do
sheen.Position=UDim2.new(-0.5,0,-0.3,0)
tween(sheen,0.9,{Position=UDim2.new(1.4,0,-0.3,0)},Enum.EasingStyle.Quad)
task.wait(4)
end
end)
local title=label(header,"HYPERD",UDim2.new(0,170,0,26),UDim2.new(0,64,0,9),22,WHITE,Enum.Font.GothamBlack)
local titleGrad=accentGradient(title,0)
label(header,"ADMIN PANEL  •  V4.0",UDim2.new(0,200,0,14),UDim2.new(0,65,0,37),10,C.Muted,Enum.Font.GothamBold)
local minBtn=button(header,"–",UDim2.fromOffset(30,30),UDim2.new(1,-74,0,17))
minBtn.TextSize=16
local closeBtn=button(header,"✕",UDim2.fromOffset(30,30),UDim2.new(1,-40,0,17))
closeBtn.MouseEnter:Connect(function()tween(closeBtn,0.12,{BackgroundColor3=C.Red})end)
closeBtn.MouseLeave:Connect(function()tween(closeBtn,0.12,{BackgroundColor3=C.Panel2})end)
local statPill
if not narrow then
local pill=new("Frame",{
BackgroundColor3=C.Panel2,Size=UDim2.fromOffset(150,26),Position=UDim2.new(1,-240,0,19),
},header)
corner(pill,13)
stroke(pill,C.Line,1,0.4)
statPill=center(label(pill,"-- FPS  •  -- ms",UDim2.fromScale(1,1),nil,11,C.Text,Enum.Font.GothamBold))
end
makeDraggable(header,main)
local sideW=narrow and 52 or 168
local sidebar=new("Frame",{
BackgroundColor3=C.Side,BackgroundTransparency=0.4,
Size=UDim2.new(0,sideW,1,-65),Position=UDim2.new(0,0,0,65),
},main)
local navList=new("ScrollingFrame",{
BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,
Size=UDim2.new(1,0,1,narrow and 0 or -30),
AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
},sidebar)
new("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},navList)
new("UIPadding",{
PaddingTop=UDim.new(0,10),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),
},navList)
if not narrow then
ui.footer=center(label(sidebar,CONFIG.ToggleKey.Name .. "  •  toggle",UDim2.new(1,0,0,20),UDim2.new(0,0,1,-26),10,C.Muted,Enum.Font.GothamBold))
end
local content=new("Frame",{
BackgroundTransparency=1,
Position=UDim2.new(0,sideW+10,0,76),
Size=UDim2.new(1,-(sideW+20),1,-88),
},main)
local wipe=new("Frame",{
BackgroundColor3=C.BG,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=20,
Position=UDim2.new(0,sideW+10,0,76),Size=UDim2.new(1,-(sideW+20),1,-88),
},main)
local sweep=new("Frame",{
BackgroundColor3=WHITE,BackgroundTransparency=1,BorderSizePixel=0,
Size=UDim2.new(1,0,0,2),ZIndex=21,
},wipe)
accentGradient(sweep,0)
ui.wipe,ui.sweep=wipe,sweep
local pages,navButtons={},{}
local function nextOrder(page)
local n=(page:GetAttribute("n")or 0)+1
page:SetAttribute("n",n)
return n
end
local function makePage(name)
local p=new("ScrollingFrame",{
Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
ScrollBarThickness=3,ScrollBarImageColor3=C.A,AutomaticCanvasSize=Enum.AutomaticSize.Y,
CanvasSize=UDim2.new(),Visible=false,
},content)
onAccent(function()p.ScrollBarImageColor3=C.A end)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},p)
new("UIPadding",{
PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,14),
PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,8),
},p)
pages[name]=p
return p
end
selectPage=function(name)
S.page=name
if ui.wipe then
ui.wipe.BackgroundTransparency=0.3
tween(ui.wipe,0.35,{BackgroundTransparency=1})
ui.sweep.Position=UDim2.fromOffset(0,0)
ui.sweep.BackgroundTransparency=0
tween(ui.sweep,0.45,{Position=UDim2.new(0,0,1,-2),BackgroundTransparency=1})
end
for n,p in pairs(pages)do
if n==name then
if not p.Visible then
p.Position=UDim2.fromOffset(0,14)
p.Visible=true
tween(p,0.25,{Position=UDim2.new()})
end
else
p.Visible=false
end
end
for n,nb in pairs(navButtons)do
local on=n==name
tween(nb.btn,0.18,{BackgroundTransparency=on and 0 or 1,TextColor3=on and C.Text or C.Muted})
tween(nb.bar,0.2,{Size=UDim2.fromOffset(3,on and 20 or 0)})
end
end
local NAV={
{"🏠","Dashboard"},{"🎯","Aimbot"},{"👥","Players"},{"🌐","Server"},{"👁","ESP"},
{"💃","Emotes"},{"✨","Character"},{"🏃","Movement"},{"🎨","Visuals"},{"⚙","Settings"},
}
table.insert(NAV,#NAV,{"🧰","Utility"})
table.insert(NAV,#NAV,{"🛠","Tools"})
table.insert(NAV,#NAV,{"⚡","Enhancements"})
if IS_OWNER then table.insert(NAV,#NAV,{"🛡","Admin"})end
for i,item in ipairs(NAV)do
local name=item[2]
local btn=new("TextButton",{
Size=UDim2.new(1,0,0,38),BackgroundColor3=C.Panel2,BackgroundTransparency=1,
AutoButtonColor=false,LayoutOrder=i,
Text=narrow and item[1]or(item[1].. "   " .. name),
TextColor3=C.Muted,Font=Enum.Font.GothamBold,TextSize=narrow and 16 or 12,
TextXAlignment=narrow and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
},navList)
corner(btn,10)
if not narrow then
new("UIPadding",{PaddingLeft=UDim.new(0,16)},btn)
end
local bar=new("Frame",{
AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=WHITE,
Position=UDim2.new(0,narrow and 2 or -13,0.5,0),Size=UDim2.fromOffset(3,0),
},btn)
corner(bar,2)
accentGradient(bar,90)
navButtons[name]={btn=btn,bar=bar}
btn.MouseEnter:Connect(function()
if S.page~=name then tween(btn,0.12,{BackgroundTransparency=0.7})end
end)
btn.MouseLeave:Connect(function()
if S.page~=name then tween(btn,0.12,{BackgroundTransparency=1})end
end)
btn.MouseButton1Click:Connect(function()
if name=="Enhancements" and ui.openEnhancements then
ui.openEnhancements()
else
selectPage(name)
end
end)
makePage(name)
end
local function section(page,text)
local f=new("Frame",{
Size=UDim2.new(1,-4,0,28),BackgroundTransparency=1,LayoutOrder=nextOrder(page),
},page)
local dot=new("Frame",{
Size=UDim2.fromOffset(4,14),Position=UDim2.new(0,2,0.5,-7),BackgroundColor3=WHITE,
},f)
corner(dot,2)
accentGradient(dot,90)
label(f,string.upper(text),UDim2.new(1,-14,1,0),UDim2.new(0,14,0,0),12,C.Text,Enum.Font.GothamBold)
return f
end
local function card(page,height)
local f=new("Frame",{
Size=UDim2.new(1,-4,0,height or 64),BackgroundColor3=C.Panel,LayoutOrder=nextOrder(page),
},page)
corner(f,12)
local cardStroke=stroke(f,C.Line,1,0.35)
new("UIGradient",{
Color=ColorSequence.new(WHITE,Color3.fromRGB(200,200,225)),Rotation=90,
},f)
f.MouseEnter:Connect(function()tween(cardStroke,0.18,{Color=C.A,Transparency=0.05})end)
f.MouseLeave:Connect(function()tween(cardStroke,0.25,{Color=C.Line,Transparency=0.35})end)
return f
end
local function titleDesc(f,titleText,desc,rightPad)
label(f,titleText,UDim2.new(1,-rightPad,0,22),UDim2.new(0,14,0,9),13,C.Text,Enum.Font.GothamBold)
local d=label(f,desc or "",UDim2.new(1,-rightPad,0,26),UDim2.new(0,14,0,31),11,C.Muted)
d.TextYAlignment=Enum.TextYAlignment.Top
d.TextTruncate=Enum.TextTruncate.AtEnd
return d
end
local function infoCard(page,height,text)
local f=card(page,height)
local l=label(f,text,UDim2.new(1,-28,1,-20),UDim2.new(0,14,0,10),12,C.Muted)
l.TextYAlignment=Enum.TextYAlignment.Top
return f,l
end
local function action(page,titleText,desc,callback,btnText)
local f=card(page,66)
titleDesc(f,titleText,desc,130)
local b=button(f,btnText or "RUN",UDim2.fromOffset(84,32),UDim2.new(1,-98,0.5,-16),true)
b.MouseButton1Click:Connect(function()
local ok,err=pcall(callback,b)
if not ok then
warn("[HYPERD] " .. tostring(err))
notify("Something went wrong","Check the Output window.",C.Red)
end
end)
return f,b
end
local toggleViews,flagCallbacks={},{}
local function refreshFlag(key)
for _,fn in ipairs(toggleViews[key]or{})do fn()end
end
local function setFlag(key,value)
flags[key]=value
local cb=flagCallbacks[key]
if cb then
local ok,err=pcall(cb,value)
if not ok then warn("[HYPERD] " .. key .. ": " .. tostring(err))end
end
refreshFlag(key)
end
local function toggle(page,titleText,desc,key,callback)
if callback then flagCallbacks[key]=callback end
local f=card(page,62)
titleDesc(f,titleText,desc,100)
local track=new("TextButton",{
Text="",AutoButtonColor=false,Size=UDim2.fromOffset(46,24),
Position=UDim2.new(1,-62,0.5,-12),BackgroundColor3=C.Off,
},f)
corner(track,12)
local grad=new("UIGradient",{Enabled=false},track)
onAccent(function()grad.Color=ColorSequence.new(C.A,C.B)end)
local knob=new("Frame",{
Size=UDim2.fromOffset(18,18),Position=UDim2.new(0,3,0.5,-9),BackgroundColor3=WHITE,
},track)
corner(knob,9)
local function refresh()
local on=flags[key]==true
grad.Enabled=on
tween(track,0.18,{BackgroundColor3=on and WHITE or C.Off})
knob.Size=UDim2.fromOffset(25,18)
tween(knob,0.32,{
Position=on and UDim2.new(1,-21,0.5,-9)or UDim2.new(0,3,0.5,-9),
Size=UDim2.fromOffset(18,18),
},Enum.EasingStyle.Back)
end
track.MouseButton1Click:Connect(function()
setFlag(key,not flags[key])
notify(titleText,flags[key]and "Enabled" or "Disabled",flags[key]and C.Green or C.Red)
end)
toggleViews[key]=toggleViews[key]or{}
table.insert(toggleViews[key],refresh)
refresh()
return f
end
local function slider(page,titleText,desc,min,max,initial,fmt,callback)
local f=card(page,80)
label(f,titleText,UDim2.new(0.62,0,0,20),UDim2.new(0,14,0,8),13,C.Text,Enum.Font.GothamBold)
local d=label(f,desc or "",UDim2.new(1,-28,0,14),UDim2.new(0,14,0,28),10,C.Muted)
d.TextTruncate=Enum.TextTruncate.AtEnd
local valueLabel=label(f,"",UDim2.new(0,100,0,20),UDim2.new(1,-114,0,8),13,C.A,Enum.Font.GothamBlack)
valueLabel.TextXAlignment=Enum.TextXAlignment.Right
onAccent(function()valueLabel.TextColor3=C.A end)
local hit=new("TextButton",{
Text="",AutoButtonColor=false,BackgroundTransparency=1,
Size=UDim2.new(1,-28,0,26),Position=UDim2.new(0,14,0,46),
},f)
local track=new("Frame",{
Size=UDim2.new(1,0,0,6),Position=UDim2.new(0,0,0.5,-3),BackgroundColor3=C.Off,
},hit)
corner(track,3)
local fill=new("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=WHITE},track)
corner(fill,3)
accentGradient(fill,0)
local knob=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(16,16),
Position=UDim2.new(0,0,0.5,0),BackgroundColor3=WHITE,
},track)
corner(knob,8)
local ks=stroke(knob,C.A,2,0)
onAccent(function()ks.Color=C.A end)
local function render(v)
local a=math.clamp((v - min)/(max - min),0,1)
fill.Size=UDim2.new(a,0,1,0)
knob.Position=UDim2.new(a,0,0.5,0)
if typeof(fmt)=="function" then
valueLabel.Text=fmt(v)
else
valueLabel.Text=tostring(v)..(fmt or "")
end
end
local function setValue(v,silent)
v=math.clamp(math.floor(v+0.5),min,max)
render(v)
if not silent then callback(v)end
end
local dragging=false
local function fromX(x)
local a=math.clamp((x - track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
setValue(min+(max - min)*a)
end
hit.InputBegan:Connect(function(input)
if input.UserInputType==Enum.UserInputType.MouseButton1
or input.UserInputType==Enum.UserInputType.Touch then
dragging=true
tween(knob,0.14,{Size=UDim2.fromOffset(22,22)},Enum.EasingStyle.Back)
fromX(input.Position.X)
end
end)
connect(UIS.InputChanged,function(input)
if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement
or input.UserInputType==Enum.UserInputType.Touch)then
fromX(input.Position.X)
end
end)
connect(UIS.InputEnded,function(input)
if input.UserInputType==Enum.UserInputType.MouseButton1
or input.UserInputType==Enum.UserInputType.Touch then
if dragging then tween(knob,0.18,{Size=UDim2.fromOffset(16,16)})end
dragging=false
end
end)
render(math.clamp(initial,min,max))
return{Set=setValue}
end
local function swatchRow(page,titleText,options,defaultIndex,callback)
local f=card(page,76)
label(f,titleText,UDim2.new(1,-28,0,20),UDim2.new(0,14,0,8),13,C.Text,Enum.Font.GothamBold)
local holder=new("Frame",{
BackgroundTransparency=1,Size=UDim2.new(1,-28,0,30),Position=UDim2.new(0,14,0,34),
},f)
new("UIListLayout",{
FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),
VerticalAlignment=Enum.VerticalAlignment.Center,
},holder)
local items={}
for i,opt in ipairs(options)do
local b=new("TextButton",{
Text="",AutoButtonColor=false,Size=UDim2.fromOffset(28,28),
BackgroundColor3=opt.color or WHITE,LayoutOrder=i,
},holder)
corner(b,14)
if opt.accent then
accentGradient(b,45)
elseif opt.pair then
new("UIGradient",{Color=ColorSequence.new(opt.pair[1],opt.pair[2]),Rotation=45},b)
end
local st=stroke(b,WHITE,2,1)
items[i]=st
b.MouseButton1Click:Connect(function()
for j,s in ipairs(items)do s.Transparency=j==i and 0 or 1 end
callback(opt,i)
end)
end
items[defaultIndex or 1].Transparency=0
return{
Select=function(i)
for j,s in ipairs(items)do s.Transparency=j==i and 0 or 1 end
end,
}
end
local function textbox(parent,placeholder,size,pos)
local t=new("TextBox",{
Size=size,Position=pos or UDim2.new(),BackgroundColor3=C.Panel2,
PlaceholderText=placeholder,PlaceholderColor3=C.Muted,Text="",
TextColor3=C.Text,Font=Enum.Font.GothamMedium,TextSize=12,
ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,
},parent)
corner(t,9)
local st=stroke(t,C.Line,1,0.3)
new("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},t)
t.Focused:Connect(function()tween(st,0.15,{Color=C.A,Transparency=0})end)
t.FocusLost:Connect(function()tween(st,0.15,{Color=C.Line,Transparency=0.3})end)
return t
end
local function stopFly()
if S.flyConn then S.flyConn:Disconnect();S.flyConn=nil end
local r,h=rootPart(),humanoid()
if r then
for _,n in ipairs({"HyperdVelocity","HyperdGyro"})do
local o=r:FindFirstChild(n)
if o then o:Destroy()end
end
end
if h then
h.PlatformStand=false
h.AutoRotate=true
end
end
local function startFly()
stopFly()
local r,h=rootPart(),humanoid()
if not r or not h then
flags.Fly=false
refreshFlag("Fly")
notify("Fly unavailable","Character not loaded.",C.Red)
return
end
local bv=new("BodyVelocity",{Name="HyperdVelocity",MaxForce=Vector3.new(1e6,1e6,1e6),P=15000},r)
local bg=new("BodyGyro",{Name="HyperdGyro",MaxTorque=Vector3.new(1e6,1e6,1e6),P=12000},r)
h.PlatformStand=true
h.AutoRotate=false
S.flyConn=RunService.RenderStepped:Connect(function()
if not flags.Fly or not r.Parent then return end
local c=cam()
local dir=Vector3.zero
if UIS:IsKeyDown(Enum.KeyCode.W)then dir+=c.CFrame.LookVector end
if UIS:IsKeyDown(Enum.KeyCode.S)then dir -=c.CFrame.LookVector end
if UIS:IsKeyDown(Enum.KeyCode.A)then dir -=c.CFrame.RightVector end
if UIS:IsKeyDown(Enum.KeyCode.D)then dir+=c.CFrame.RightVector end
if UIS:IsKeyDown(Enum.KeyCode.Space)then dir+=Vector3.yAxis end
if UIS:IsKeyDown(Enum.KeyCode.LeftControl)then dir -=Vector3.yAxis end
bv.Velocity=dir.Magnitude>0 and dir.Unit*speeds.fly or Vector3.zero
bg.CFrame=c.CFrame
end)
end
local function clearESP(p)
if highlights[p]then highlights[p]:Destroy();highlights[p]=nil end
if labels[p]then labels[p]:Destroy();labels[p]=nil end
end
local function isValidESPTarget(p)
if p==LP or not p.Character then return false end
if flags.TeamCheck and LP.Team and p.Team==LP.Team then return false end
local theirRoot=p.Character:FindFirstChild("HumanoidRootPart")
if not theirRoot then return false end
local mine=rootPart()
if mine and esp.maxDist and(theirRoot.Position - mine.Position).Magnitude>esp.maxDist then return false end
return true
end
local function updateESP()
for _,p in ipairs(Players:GetPlayers())do
if isValidESPTarget(p)then
local ch=p.Character
local r=ch:FindFirstChild("HumanoidRootPart")
local h=ch:FindFirstChildOfClass("Humanoid")
if flags.ESPOutline then
if not highlights[p]or highlights[p].Parent~=ch then
if highlights[p]then highlights[p]:Destroy()end
highlights[p]=new("Highlight",{
Name="HyperdESP",FillColor=esp.fill,OutlineColor=esp.outline,
FillTransparency=0.7,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
},ch)
end
elseif highlights[p]then
highlights[p]:Destroy()
highlights[p]=nil
end
if flags.ESPNames or flags.ESPDistance or flags.ESPHealth then
if not labels[p]or labels[p].Parent~=ch then
if labels[p]then labels[p]:Destroy()end
local bb=new("BillboardGui",{
Name="HyperdESPLabel",Size=UDim2.fromOffset(200,60),
StudsOffset=Vector3.new(0,3.2,0),AlwaysOnTop=true,Adornee=r,
},ch)
new("TextLabel",{
Name="Label",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
Font=Enum.Font.GothamBold,TextSize=12,TextColor3=esp.outline,
TextStrokeTransparency=0.25,TextStrokeColor3=Color3.new(0,0,0),
},bb)
labels[p]=bb
end
local bits={}
if flags.ESPNames then table.insert(bits,p.DisplayName)end
local myRoot=rootPart()
if flags.ESPDistance and myRoot then
table.insert(bits,math.floor((myRoot.Position - r.Position).Magnitude).. " studs")
end
if flags.ESPHealth and h then
table.insert(bits,"HP " .. math.floor(h.Health).. "/" .. math.floor(h.MaxHealth))
end
labels[p].Label.Text=table.concat(bits,"\n")
labels[p].Label.TextColor3=esp.outline
elseif labels[p]then
labels[p]:Destroy()
labels[p]=nil
end
else
clearESP(p)
end
end
end
local tracers={}
local function clearTracer(p)
if tracers[p]then tracers[p]:Destroy();tracers[p]=nil end
end
local function updateTracers()
local c=cam()
if not c then return end
if not flags.ESPTracers then
for p in pairs(tracers)do clearTracer(p)end
return
end
local vp=c.ViewportSize
local origin=Vector2.new(vp.X/2,vp.Y)
for _,p in ipairs(Players:GetPlayers())do
local r=isValidESPTarget(p)and p.Character:FindFirstChild("HumanoidRootPart")
local line=tracers[p]
if r then
local v=c:WorldToViewportPoint(r.Position)
if v.Z>0 then
if not line then
line=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),BorderSizePixel=0,BackgroundColor3=esp.fill,
},hud)
tracers[p]=line
end
local d=Vector2.new(v.X,v.Y)- origin
line.Position=UDim2.fromOffset(origin.X+d.X/2,origin.Y+d.Y/2)
line.Size=UDim2.fromOffset(d.Magnitude,1.5)
line.Rotation=math.deg(math.atan2(d.Y,d.X))
line.BackgroundColor3=esp.fill
line.Visible=true
elseif line then
line.Visible=false
end
else
clearTracer(p)
end
end
end
local orbit={speed=6,radius=14,height=5,angle=0}
local function orbitStep(dt)
if not flags.OrbitCam then return end
local p=S.selected
local r=p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local c=cam()
if not r or not c then
setFlag("OrbitCam",false)
notify("Orbit camera","Select a player first.",C.Red)
return
end
orbit.angle+=dt*orbit.speed*0.25
local focus=r.Position
local pos=focus+Vector3.new(math.cos(orbit.angle)*orbit.radius,orbit.height,math.sin(orbit.angle)*orbit.radius)
c.CameraType=Enum.CameraType.Scriptable
c.CFrame=CFrame.lookAt(pos,focus)
end
local function setGlow(on)
if S.glow then S.glow:Destroy();S.glow=nil end
local ch=character()
if on and ch then
S.glow=new("Highlight",{
Name="HyperdGlow",FillColor=C.A,OutlineColor=C.B,FillTransparency=0.65,
},ch)
end
end
onAccent(function()
if S.glow then S.glow.FillColor=C.A;S.glow.OutlineColor=C.B end
end)
local function removeTrail()
for _,obj in ipairs(trailParts)do
if obj and obj.Parent then obj:Destroy()end
end
table.clear(trailParts)
end
local function setTrail(on)
removeTrail()
if not on then return end
local r=rootPart()
if not r then return end
local a0=new("Attachment",{Position=Vector3.new(-0.6,0,0)},r)
local a1=new("Attachment",{Position=Vector3.new(0.6,0,0)},r)
local tr=new("Trail",{
Attachment0=a0,Attachment1=a1,Lifetime=0.5,LightEmission=1,
Color=ColorSequence.new(C.A,C.B),
Transparency=NumberSequence.new(0.2,1),
},r)
table.insert(trailParts,a0)
table.insert(trailParts,a1)
table.insert(trailParts,tr)
end
local function setBlur(on)
if S.blur then S.blur:Destroy();S.blur=nil end
local found=Lighting:FindFirstChild("HyperdBlur")
if found then found:Destroy()end
if on then
S.blur=new("BlurEffect",{Name="HyperdBlur",Size=8},Lighting)
end
end
local function setRainbow(on)
if S.rainbow then S.rainbow:Destroy();S.rainbow=nil end
local ch=character()
if on and ch then
S.rainbow=new("Highlight",{Name="HyperdRainbow",FillTransparency=0.45,OutlineTransparency=0},ch)
end
end
local function setAura(on)
if S.aura then S.aura:Destroy();S.aura=nil end
local r=rootPart()
if on and r then
S.aura=new("ParticleEmitter",{
Name="HyperdAura",Texture="rbxasset://textures/particles/sparkles_main.dds",
Color=ColorSequence.new(C.A,C.B),LightEmission=1,Rate=30,
Lifetime=NumberRange.new(0.8,1.4),Speed=NumberRange.new(1,3),
SpreadAngle=Vector2.new(180,180),RotSpeed=NumberRange.new(-90,90),
Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.7),NumberSequenceKeypoint.new(1,0)}),
Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}),
},r)
end
end
onAccent(function()
if S.aura then S.aura.Color=ColorSequence.new(C.A,C.B)end
end)
local function setBloom(on)
if S.bloom then S.bloom:Destroy();S.bloom=nil end
if on then
S.bloom=new("BloomEffect",{Name="HyperdBloom",Intensity=1,Size=28,Threshold=0.85},Lighting)
end
end
local function getCC()
if not S.cc or not S.cc.Parent then
S.cc=new("ColorCorrectionEffect",{Name="HyperdCC"},Lighting)
end
return S.cc
end
local function updateLightingFlags()
local fb=flags.Fullbright
Lighting.Ambient=fb and Color3.fromRGB(190,190,190)or original.ambient
Lighting.OutdoorAmbient=fb and Color3.fromRGB(190,190,190)or original.outdoor
Lighting.GlobalShadows=(not fb and not flags.FPSBoost)and original.shadows or false
end
local function stopAnimation()
if S.activeAnim then
pcall(function()
S.activeAnim:Stop(0.15)
S.activeAnim:Destroy()
end)
S.activeAnim=nil
end
end
local function playAnimationId(name,id)
local h=humanoid()
if not h then
notify("Emote unavailable","Character not loaded.",C.Red)
return
end
stopAnimation()
local animator=h:FindFirstChildOfClass("Animator")or new("Animator",nil,h)
local anim=new("Animation",{AnimationId="rbxassetid://" .. tostring(id)})
local ok,track=pcall(function()return animator:LoadAnimation(anim)end)
if not ok or not track then
anim:Destroy()
notify("Animation failed","Check the ID and its permissions.",C.Red)
return
end
track.Looped=true
track:Play(0.15)
track:AdjustSpeed(S.animSpeed)
S.activeAnim=track
notify("Emote","Playing " .. name,C.Green)
end
local function applyJump()
local h=humanoid()
if h then
h.UseJumpPower=true
h.JumpPower=flags.HighJump and 100 or speeds.jump
end
end
local liveUpdaters={}
do
local dp=pages.Dashboard
section(dp,"Welcome")
local banner=new("Frame",{
Size=UDim2.new(1,-4,0,108),BackgroundColor3=WHITE,LayoutOrder=nextOrder(dp),
},dp)
corner(banner,14)
ui.bannerGrad=accentGradient(banner,20)
local bubble=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,-30,0,10),
Size=UDim2.fromOffset(170,170),BackgroundColor3=WHITE,BackgroundTransparency=0.85,
},banner)
corner(bubble,1000)
label(banner,"WELCOME BACK",UDim2.new(1,-28,0,16),UDim2.new(0,16,0,12),10,Color3.fromRGB(255,255,255),Enum.Font.GothamBold).TextTransparency=0.2
label(banner,string.upper(LP.DisplayName),UDim2.new(1,-28,0,34),UDim2.new(0,16,0,28),26,WHITE,Enum.Font.GothamBlack)
local tag=label(banner,(IS_OWNER and "Owner access. Open the Admin tab to give HYPERD to players or bring them to you.")or "HYPERD is online. Hold RMB to aim-lock. Your panel hotkey shows or hides this window.",
UDim2.new(1,-28,0,30),UDim2.new(0,16,0,66),11,WHITE)
tag.TextTransparency=0.15
tag.TextYAlignment=Enum.TextYAlignment.Top
local statsCard=card(dp,78)
local stat={}
for i,c in ipairs({{"FPS","fps"},{"PING","ping"},{"PLAYERS","players"},{"UPTIME","uptime"}})do
local cell=new("Frame",{
BackgroundTransparency=1,Size=UDim2.new(0.25,0,1,0),Position=UDim2.new((i - 1)*0.25,0,0,0),
},statsCard)
stat[c[2]]=center(label(cell,"--",UDim2.new(1,0,0,30),UDim2.new(0,0,0,14),narrow and 15 or 20,C.Text,Enum.Font.GothamBlack))
center(label(cell,c[1],UDim2.new(1,0,0,14),UDim2.new(0,0,0,48),9,C.Muted,Enum.Font.GothamBold))
end
ui.stat=stat
local graph=card(dp,100)
label(graph,"FRAME RATE",UDim2.new(1,-28,0,16),UDim2.new(0,14,0,8),10,C.Muted,Enum.Font.GothamBold)
local barsHolder=new("Frame",{
BackgroundTransparency=1,Size=UDim2.new(1,-28,0,60),Position=UDim2.new(0,14,0,28),
},graph)
local N=30
local bars,hist={},{}
for i=1,N do
local bar=new("Frame",{
AnchorPoint=Vector2.new(0,1),BackgroundColor3=WHITE,BorderSizePixel=0,
Position=UDim2.new((i - 1)/N,1,1,0),Size=UDim2.new(1/N,-2,0.04,0),
},barsHolder)
corner(bar,2)
accentGradient(bar,90)
bars[i]=bar
end
ui.pushFps=function(fps)
table.insert(hist,fps)
if#hist>N then table.remove(hist,1)end
local offset=N -#hist
for i=1,N do
local v=hist[i - offset]
if v then
tween(bars[i],0.3,{Size=UDim2.new(1/N,-2,math.clamp(v/120,0.04,1),0)})
end
end
end
section(dp,"Quick toggles")
toggle(dp,"Aimbot","Hold RMB to lock onto heads inside the FOV circle.","Aimbot")
toggle(dp,"Fly","WASD move, Space up, Ctrl down.","Fly")
toggle(dp,"Player outlines","Highlight every player through walls.","ESPOutline")
section(dp,"Shortcuts")
action(dp,"Aimbot settings","Adjust FOV size, pull strength and more.",function()selectPage("Aimbot")end,"OPEN")
if CAN_EXPLORE then
action(dp,"Dex Explorer","Browse and inspect every instance you can see.",function()ui.openExplorer()end,"OPEN")
end
action(dp,"Reset all","Turn everything off and restore defaults.",function()resetAll()end,"RESET")
end
do
local ap=pages.Aimbot
section(ap,"Aimbot")
local _,statusLabel=infoCard(ap,62,"Idle  •  hold RMB to lock on")
statusLabel.Font=Enum.Font.GothamBold
statusLabel.TextColor3=C.Text
statusLabel.TextSize=13
statusLabel.TextYAlignment=Enum.TextYAlignment.Center
ui.aimStatus=statusLabel
toggle(ap,"Enable aimbot","Hold RMB to lock onto the head of the closest player in the circle.","Aimbot")
sliders.aimFov=slider(ap,"FOV size","Radius of the lock-on circle in pixels.",20,500,aim.fov," px",function(v)
aim.fov=v
fovCircle.Size=UDim2.fromOffset(v*2,v*2)
end)
sliders.aimStrength=slider(ap,"Pull strength","How hard the camera is dragged to the head. 100 = instant snap.",1,100,aim.strength,"%",function(v)
aim.strength=v
end)
toggle(ap,"Show FOV circle","Draw the circle on screen while the aimbot is enabled.","AimShowFOV")
sliders.aimThick=slider(ap,"Circle thickness","Line width of the FOV circle.",1,6,aim.thick," px",function(v)
aim.thick=v
fovStroke.Thickness=v
end)
do
local opts={{accent=true,name="Theme"}}
for _,col in ipairs({
Color3.fromRGB(255,255,255),Color3.fromRGB(255,75,95),Color3.fromRGB(70,255,140),
Color3.fromRGB(0,215,255),Color3.fromRGB(255,205,70),Color3.fromRGB(255,70,160),
})do
table.insert(opts,{color=col})
end
ui.fovSwatch=swatchRow(ap,"Circle color",opts,1,function(opt)
aim.color=opt.color
applyFovColor()
end)
end
toggle(ap,"Filled circle","Add a soft tint inside the FOV circle.","AimFill",function(on)
fovCircle.BackgroundTransparency=on and 0.88 or 1
end)
toggle(ap,"Sticky lock","Stay on the same target while RMB is held and they stay in range.","AimSticky")
toggle(ap,"Wall check","Only lock onto players you have a clear line of sight to.","AimWall")
toggle(ap,"Ignore teammates","Skip players on your team.","AimTeam")
toggle(ap,"Target marker","Show a ring on the locked target.","AimMarker")
toggle(ap,"Circle follows cursor","Off = circle stays at the screen center.","AimFollowCursor")
local _,partBtn=action(ap,"Aim point","Which body part the aimbot pulls toward.",function(b)
aimPartIndex=aimPartIndex%#AIM_PARTS+1
b.Text=string.upper(AIM_PARTS[aimPartIndex])
end,string.upper(AIM_PARTS[aimPartIndex]))
ui.partBtn=partBtn
end
local aimRayParams=RaycastParams.new()
aimRayParams.FilterType=Enum.RaycastFilterType.Exclude
local function aimPartFor(ch)
local mode=AIM_PARTS[aimPartIndex]
if mode=="Head" then
return ch:FindFirstChild("Head")
elseif mode=="Chest" then
return ch:FindFirstChild("UpperTorso")or ch:FindFirstChild("Torso")
end
return ch:FindFirstChild("HumanoidRootPart")
end
local function aimCandidate(p)
if p==LP then return nil end
local ch=p.Character
if not ch then return nil end
local hum=ch:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health<=0 then return nil end
if flags.AimTeam and LP.Team~=nil and p.Team==LP.Team then return nil end
local part=aimPartFor(ch)
if not part then return nil end
return part,ch
end
local function lineOfSight(c,part,ch)
local origin=c.CFrame.Position
aimRayParams.FilterDescendantsInstances={LP.Character}
local hit=workspace:Raycast(origin,part.Position - origin,aimRayParams)
return hit==nil or hit.Instance:IsDescendantOf(ch)
end
local function setLocked(p)
if S.locked==p then return end
S.locked=p
if ui.aimStatus then
ui.aimStatus.Text=p and("Locked  •  " .. p.DisplayName)or "Idle  •  hold RMB to lock on"
ui.aimStatus.TextColor3=p and C.Green or C.Text
end
end
local function aimStep(dt)
local c=cam()
if not c then return end
local center2=flags.AimFollowCursor and UIS:GetMouseLocation()or(c.ViewportSize/2)
local vipOn=flags.VipAimbot and LP:GetAttribute("HyperdVIP")==true and ui.vipStep~=nil
local showCircle=(vipOn or flags.Aimbot)and flags.AimShowFOV
fovCircle.Visible=showCircle
if showCircle then
fovCircle.Position=UDim2.fromOffset(center2.X,center2.Y)
local radius=vipOn and vip.fov or aim.fov
fovCircle.Size=UDim2.fromOffset(radius*2,radius*2)
end
if vipOn then
ui.vipStep(dt,c,center2)
return
end
local holding=flags.Aimbot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
if not holding then
if S.locked then setLocked(nil)end
marker.Visible=false
fovStroke.Thickness=aim.thick
fovStroke.Transparency=0.1
return
end
local function evaluate(p)
local part,ch=aimCandidate(p)
if not part then return nil end
local v,onScreen=c:WorldToViewportPoint(part.Position)
if not onScreen then return nil end
local sp=Vector2.new(v.X,v.Y)
local d=(sp - center2).Magnitude
if d>aim.fov then return nil end
if flags.AimWall and not lineOfSight(c,part,ch)then return nil end
return part,d,sp
end
local targetPart,screenPos
if flags.AimSticky and S.locked then
local part,_,sp=evaluate(S.locked)
if part then
targetPart,screenPos=part,sp
else
setLocked(nil)
end
end
if not targetPart then
local bestD,bestP=math.huge,nil
for _,p in ipairs(Players:GetPlayers())do
local part,d,sp=evaluate(p)
if part and d<bestD then
bestD,bestP,targetPart,screenPos=d,p,part,sp
end
end
setLocked(bestP)
end
if not targetPart then
marker.Visible=false
fovStroke.Thickness=aim.thick
fovStroke.Transparency=0.1
return
end
local camCF=c.CFrame
local goal=CFrame.lookAt(camCF.Position,targetPart.Position)
local s=aim.strength/100
local alpha
if s>=1 then
alpha=1
else
local pull=math.max(s*s,0.004)
alpha=math.clamp(1 -(1 - pull)^(dt*60),0,1)
end
c.CFrame=camCF:Lerp(goal,alpha)
fovStroke.Thickness=aim.thick+1
fovStroke.Transparency=0
marker.Visible=flags.AimMarker
if marker.Visible then
marker.Position=UDim2.fromOffset(screenPos.X,screenPos.Y)
end
end
RunService:BindToRenderStep("HyperdAim",Enum.RenderPriority.Camera.Value+1,aimStep)
do
local pp=pages.Players
section(pp,"Player selector")
local selector=card(pp,64)
selector.ClipsDescendants=true
local pickBtn=button(selector,"Choose a player  ▼",UDim2.new(1,-28,0,36),UDim2.new(0,14,0,14))
pickBtn.TextXAlignment=Enum.TextXAlignment.Left
new("UIPadding",{PaddingLeft=UDim.new(0,12)},pickBtn)
ui.pickBtn=pickBtn
local list=new("ScrollingFrame",{
Size=UDim2.new(1,-28,0,110),Position=UDim2.new(0,14,0,58),
BackgroundColor3=C.BG,BorderSizePixel=0,ScrollBarThickness=3,
AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Visible=false,
},selector)
corner(list,9)
new("UIListLayout",{Padding=UDim.new(0,4)},list)
new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,6)},list)
local function closeList()
list.Visible=false
tween(selector,0.18,{Size=UDim2.new(1,-4,0,64)})
end
local function refreshPlayers()
for _,child in ipairs(list:GetChildren())do
if child:IsA("TextButton")then child:Destroy()end
end
for _,target in ipairs(Players:GetPlayers())do
if target~=LP then
local b=button(list,target.DisplayName .. "  @" .. target.Name,UDim2.new(1,0,0,30))
b.TextXAlignment=Enum.TextXAlignment.Left
new("UIPadding",{PaddingLeft=UDim.new(0,10)},b)
b.MouseButton1Click:Connect(function()
S.selected=target
pickBtn.Text=target.DisplayName .. "  ✓"
closeList()
end)
end
end
end
pickBtn.MouseButton1Click:Connect(function()
if list.Visible then
closeList()
else
refreshPlayers()
list.Visible=true
tween(selector,0.18,{Size=UDim2.new(1,-4,0,184)})
end
end)
connect(Players.PlayerAdded,function()if list.Visible then refreshPlayers()end end)
connect(Players.PlayerRemoving,function(p)
clearESP(p)
clearTracer(p)
if S.selected==p then
S.selected=nil
pickBtn.Text="Choose a player  ▼"
end
if S.locked==p then setLocked(nil)end
if list.Visible then task.defer(refreshPlayers)end
end)
local _,infoLabel=infoCard(pp,62,"No player selected.")
infoLabel.TextColor3=C.Text
infoLabel.TextYAlignment=Enum.TextYAlignment.Center
table.insert(liveUpdaters,function()
local p=S.selected
if not p then
infoLabel.Text="No player selected."
return
end
local ch=p.Character
local h=ch and ch:FindFirstChildOfClass("Humanoid")
local r=ch and ch:FindFirstChild("HumanoidRootPart")
local mine=rootPart()
local dist=(r and mine)and(math.floor((r.Position - mine.Position).Magnitude).. " studs")or "—"
local hp=h and(math.floor(h.Health).. "/" .. math.floor(h.MaxHealth))or "—"
infoLabel.Text=p.DisplayName .. "  @" .. p.Name .. "\nHP " .. hp .. "   •   " .. dist ..
"   •   Team: " ..(p.Team and p.Team.Name or "none")
end)
section(pp,"Actions")
action(pp,"Teleport to player","Move beside the selected player.",function()
if not S.selected then
notify("Choose a player","Select someone first.",C.Red)
return
end
local r=rootPart()
local tr=S.selected.Character and S.selected.Character:FindFirstChild("HumanoidRootPart")
if r and tr then
r.CFrame=tr.CFrame*CFrame.new(0,0,4)
else
notify("Teleport failed","Character not loaded.",C.Red)
end
end,"GO")
action(pp,"Bring player to me","Teleports the selected player to you. Owner only, checked by the server.",function()
if not S.selected then
notify("Choose a player","Select someone first.",C.Red)
return
end
if not(REMOTE and IS_OWNER)then
notify("Owner only","Owner access is required.",C.Red)
return
end
REMOTE:FireServer("bring",S.selected.UserId)
end,"BRING")
action(pp,"Spectate player","Point your camera at the selected player.",function()
if not S.selected then
notify("Choose a player","Select someone first.",C.Red)
return
end
local h=S.selected.Character and S.selected.Character:FindFirstChildOfClass("Humanoid")
if h and cam()then
cam().CameraSubject=h
S.spectating=true
notify("Spectating",S.selected.DisplayName,C.A)
else
notify("Spectate failed","Character not loaded.",C.Red)
end
end,"WATCH")
action(pp,"Stop spectating","Return the camera to your character.",function()
local h=humanoid()
if h and cam()then cam().CameraSubject=h end
S.spectating=false
end,"STOP")
section(pp,"Flight")
toggle(pp,"Fly","WASD move, Space up, Ctrl down.","Fly",function(on)
if on then startFly()else stopFly()end
end)
sliders.fly=slider(pp,"Flight speed","Studs per second while flying.",20,250,speeds.fly,"",function(v)
speeds.fly=v
end)
section(pp,"Orbit camera")
toggle(pp,"Orbit camera","Your camera circles the selected player.","OrbitCam",function(on)
local c=cam()
if on then
if not S.selected then
flags.OrbitCam=false
refreshFlag("OrbitCam")
notify("Orbit camera","Select a player first.",C.Red)
end
elseif c then
c.CameraType=Enum.CameraType.Custom
local h=humanoid()
if h then c.CameraSubject=h end
end
end)
sliders.orbitSpeed=slider(pp,"Orbit speed","How fast the camera circles.",1,30,orbit.speed,"",function(v)
orbit.speed=v
end)
sliders.orbitRadius=slider(pp,"Orbit radius","Distance from the player.",4,60,orbit.radius," studs",function(v)
orbit.radius=v
end)
sliders.orbitHeight=slider(pp,"Orbit height","Camera height above the player.",-10,40,orbit.height," studs",function(v)
orbit.height=v
end)
end
do
local sv=pages.Server
section(sv,"Current server")
local _,infoLabel=infoCard(sv,150,"")
infoLabel.TextColor3=C.Text
infoLabel.TextSize=12
table.insert(liveUpdaters,function()
local ping="—"
pcall(function()
ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()).. " ms"
end)
infoLabel.Text=
"Place ID     " .. tostring(game.PlaceId)..
"\nJob ID         " ..(game.JobId~="" and game.JobId or "Studio test server")..
"\nPlayers       " ..#Players:GetPlayers().. " / " .. Players.MaxPlayers ..
"\nUptime        " .. fmtTime(workspace.DistributedGameTime)..
"\nPing            " .. ping ..
"\nRegion        not exposed by Roblox"
end)
section(sv,"Server actions")
action(sv,"Rejoin this server","Teleport back into the same server instance.",function()
local ok,err=pcall(function()
TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP)
end)
if not ok then notify("Rejoin failed","Not available here (Studio?).",C.Red);warn(err)end
end,"REJOIN")
action(sv,"Join a new server","Teleport into a fresh server of this place.",function()
local ok,err=pcall(function()TeleportService:Teleport(game.PlaceId,LP)end)
if not ok then notify("Teleport failed","Not available here (Studio?).",C.Red);warn(err)end
end,"JOIN")
section(sv,"Server browser")
infoCard(sv,92,"Roblox does not expose a public server directory or server countries to a LocalScript. To list other live servers, connect a backend you control — never put private API keys in this script.")
end
do
local ep=pages.ESP
section(ep,"Player ESP")
toggle(ep,"Player outlines","Highlight player characters through walls.","ESPOutline")
toggle(ep,"Name labels","Show names above players.","ESPNames")
toggle(ep,"Distance labels","Show distance in studs.","ESPDistance")
toggle(ep,"Health labels","Show current health.","ESPHealth")
toggle(ep,"Team check","Hide teammates from ESP.","TeamCheck")
toggle(ep,"Tracers","Draw lines from the bottom of the screen to players.","ESPTracers")
swatchRow(ep,"ESP color",{
{color=C.A,name="Theme",accent=true},
{color=Color3.fromRGB(255,75,95)},
{color=Color3.fromRGB(70,255,140)},
{color=Color3.fromRGB(0,215,255)},
{color=Color3.fromRGB(255,205,70)},
{color=Color3.fromRGB(255,255,255)},
},1,function(opt)
esp.fill=opt.accent and C.A or opt.color
esp.outline=WHITE
for _,hi in pairs(highlights)do
hi.FillColor=esp.fill
hi.OutlineColor=esp.outline
end
end)
connect(RunService.Heartbeat,updateESP)
end
do
local em=pages.Emotes
section(em,"Dance & emote center")
infoCard(em,66,"Built-in emotes work on avatars that support them. Custom slots use animation IDs from CONFIG.CustomDances, or paste one below.")
local searchWrap=new("Frame",{
Size=UDim2.new(1,-4,0,38),BackgroundTransparency=1,LayoutOrder=nextOrder(em),
},em)
local search=textbox(searchWrap,"Search emotes...",UDim2.fromScale(1,1))
local idWrap=new("Frame",{
Size=UDim2.new(1,-4,0,38),BackgroundTransparency=1,LayoutOrder=nextOrder(em),
},em)
local idBox=textbox(idWrap,"Animation ID...",UDim2.new(1,-96,1,0))
local idPlay=button(idWrap,"PLAY",UDim2.fromOffset(86,38),UDim2.new(1,-86,0,0),true)
idPlay.MouseButton1Click:Connect(function()
local id=tonumber(idBox.Text)
if id and id>0 then
playAnimationId("ID " .. id,id)
else
notify("Invalid ID","Enter a numeric animation ID.",C.Red)
end
end)
action(em,"Stop current emote","Stop the playing animation.",function()
stopAnimation()
local h=humanoid()
if h then
for _,t in ipairs(h:GetPlayingAnimationTracks())do
if t.Priority==Enum.AnimationPriority.Action then pcall(function()t:Stop(0.15)end)end
end
end
end,"STOP")
sliders.animSpeed=slider(em,"Emote speed","Playback speed for custom animations.",10,300,100,"%",function(v)
S.animSpeed=v/100
if S.activeAnim then pcall(function()S.activeAnim:AdjustSpeed(S.animSpeed)end)end
end)
local grid=new("Frame",{
Size=UDim2.new(1,-4,0,10),AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,LayoutOrder=nextOrder(em),
},em)
new("UIGridLayout",{
CellSize=UDim2.new(1/3,-6,0,40),CellPadding=UDim2.fromOffset(8,8),
SortOrder=Enum.SortOrder.LayoutOrder,
},grid)
local emotes={
{"Dance","dance"},{"Dance 2","dance2"},{"Dance 3","dance3"},{"Wave","wave"},
{"Point","point"},{"Cheer","cheer"},{"Laugh","laugh"},
}
for i=1,40 do
local cd=CONFIG.CustomDances[i]
if cd then
table.insert(emotes,{cd[1],"custom:" .. tostring(cd[2])})
else
table.insert(emotes,{"Custom Dance " .. string.format("%02d",i),"custom:0"})
end
end
local emoteButtons={}
local builtin={dance=true,dance2=true,dance3=true,wave=true,point=true,cheer=true,laugh=true}
local function playEmote(name,id)
local h=humanoid()
if not h then
notify("Emote unavailable","Character not loaded.",C.Red)
return
end
if builtin[id]then
stopAnimation()
local ok=pcall(function()h:PlayEmote(id)end)
if ok then
notify("Emote","Playing " .. name,C.Green)
else
notify("Emote unavailable","This avatar may not support it.",C.Red)
end
return
end
local animId=tonumber(string.match(id,"^custom:(%d+)$"))
if not animId or animId<=0 then
notify("Needs animation ID","Add one in CONFIG.CustomDances.",C.Yellow)
return
end
playAnimationId(name,animId)
end
local function rebuild()
for _,b in ipairs(emoteButtons)do b:Destroy()end
table.clear(emoteButtons)
local q=string.lower(search.Text)
for i,e in ipairs(emotes)do
if q=="" or string.find(string.lower(e[1]),q,1,true)then
local b=button(grid,"🎵 " .. e[1],UDim2.new())
b.LayoutOrder=i
b.TextSize=11
b.TextTruncate=Enum.TextTruncate.AtEnd
table.insert(emoteButtons,b)
b.MouseButton1Click:Connect(function()playEmote(e[1],e[2])end)
end
end
end
search:GetPropertyChangedSignal("Text"):Connect(rebuild)
rebuild()
end
do
local cp=pages.Character
section(cp,"Character utilities")
action(cp,"Heal","Restore health to maximum.",function()
local h=humanoid()
if h then h.Health=h.MaxHealth end
end,"HEAL")
action(cp,"Reset character","Respawn your character.",function()
local h=humanoid()
if h then h.Health=0 end
end,"RESET")
toggle(cp,"Auto-heal","Heal whenever health drops below half.","AutoHeal",function(on)
if S.healConn then S.healConn:Disconnect();S.healConn=nil end
if on then
S.healConn=RunService.Heartbeat:Connect(function()
local h=humanoid()
if flags.AutoHeal and h and h.Health>0 and h.Health<h.MaxHealth*0.5 then
h.Health=h.MaxHealth
end
end)
end
end)
toggle(cp,"High jump","Boost jump power to 100.","HighJump",function()applyJump()end)
toggle(cp,"Infinite jump","Jump again while in mid-air.","InfJump")
connect(UIS.JumpRequest,function()
if flags.InfJump then
local h=humanoid()
if h then h:ChangeState(Enum.HumanoidStateType.Jumping)end
end
end)
end
do
local mp=pages.Movement
section(mp,"Movement")
sliders.walk=slider(mp,"Walk speed","Base walking speed.",8,150,speeds.walk,"",function(v)
speeds.walk=v
local h=humanoid()
if h and not S.sprinting then h.WalkSpeed=v end
end)
sliders.jump=slider(mp,"Jump power","Base jump power.",20,200,speeds.jump,"",function(v)
speeds.jump=v
applyJump()
end)
toggle(mp,"Sprint","Hold Left Shift to run faster.","Sprint",function(on)
if not on then
S.sprinting=false
local h=humanoid()
if h then h.WalkSpeed=speeds.walk end
end
end)
sliders.sprint=slider(mp,"Sprint speed","Walk speed while Left Shift is held.",16,150,speeds.sprint,"",function(v)
speeds.sprint=v
if S.sprinting then
local h=humanoid()
if h then h.WalkSpeed=v end
end
end)
toggle(mp,"Noclip","Walk through walls and objects.","Noclip")
toggle(mp,"Ctrl + click teleport","Hold Left Ctrl and click to teleport there.","ClickTP")
sliders.gravity=slider(mp,"Gravity","World gravity (default is about 196).",10,400,
math.floor(original.gravity+0.5),"",function(v)
workspace.Gravity=v
end)
connect(RunService.Stepped,function()
if not flags.Noclip then return end
local ch=LP.Character
if not ch then return end
for _,part in ipairs(ch:GetDescendants())do
if part:IsA("BasePart")and part.CanCollide then part.CanCollide=false end
end
end)
connect(UIS.InputBegan,function(input,processed)
if processed or not flags.ClickTP then return end
if input.UserInputType==Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl)then
local c,r=cam(),rootPart()
if not c or not r then return end
local m=UIS:GetMouseLocation()
local ray=c:ViewportPointToRay(m.X,m.Y)
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={LP.Character}
local hit=workspace:Raycast(ray.Origin,ray.Direction*2000,params)
if hit then r.CFrame=CFrame.new(hit.Position+Vector3.new(0,3,0))end
end
end)
connect(UIS.InputBegan,function(input,processed)
if not processed and input.KeyCode==Enum.KeyCode.LeftShift and flags.Sprint then
local h=humanoid()
if h then S.sprinting=true;h.WalkSpeed=speeds.sprint end
end
end)
connect(UIS.InputEnded,function(input)
if input.KeyCode==Enum.KeyCode.LeftShift and S.sprinting then
S.sprinting=false
local h=humanoid()
if h then h.WalkSpeed=speeds.walk end
end
end)
end
do
local vp=pages.Visuals
section(vp,"Visual effects")
toggle(vp,"Avatar glow","Wrap your avatar in a theme-colored highlight.","Glow",setGlow)
toggle(vp,"Neon trail","Leave a glowing trail while moving.","Trail",setTrail)
toggle(vp,"Depth blur","Apply a subtle blur effect.","Blur",setBlur)
sliders.fov=slider(vp,"Field of view","Camera field of view.",40,120,math.floor(original.fov+0.5),"°",function(v)
if cam()then cam().FieldOfView=v end
end)
sliders.brightness=slider(vp,"Brightness","World lighting brightness.",0,100,
math.floor(original.brightness*10+0.5),function(v)return string.format("%.1f",v/10)end,function(v)
Lighting.Brightness=v/10
end)
section(vp,"Avatar effects")
toggle(vp,"Rainbow avatar","Cycle your avatar through every color.","Rainbow",setRainbow)
toggle(vp,"Particle aura","Sparkles drift around your character.","Aura",setAura)
section(vp,"World & lighting")
toggle(vp,"Bloom","Add a cinematic glow to bright areas.","Bloom",setBloom)
toggle(vp,"Fullbright","Light up dark areas and remove shadows.","Fullbright",updateLightingFlags)
toggle(vp,"FPS boost","Lower quality and shadows for more frames.","FPSBoost",function(on)
pcall(function()
settings().Rendering.QualityLevel=on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
end)
updateLightingFlags()
end)
sliders.sat=slider(vp,"Saturation","Color intensity of the whole screen.",-100,100,0,"%",function(v)
getCC().Saturation=v/100
end)
sliders.time=slider(vp,"Time of day","Hour of the day (0-24).",0,24,
math.floor(original.clock+0.5)," h",function(v)
Lighting.ClockTime=v
end)
section(vp,"Crosshair")
toggle(vp,"Custom crosshair","Draw a crosshair in the center of the screen.","Crosshair",function(on)
crosshair.Visible=on
end)
sliders.xsize=slider(vp,"Crosshair size","Length of each crosshair arm.",2,30,xhair.len," px",function(v)
xhair.len=v
layoutCrosshair()
end)
sliders.xgap=slider(vp,"Crosshair gap","Space in the middle.",0,20,xhair.gap," px",function(v)
xhair.gap=v
layoutCrosshair()
end)
end
do
local exWin,treeScroll,propList,pathBox,searchBox,destroyBtn
local exOpen=false
local selected=nil
local expanded={[game]=true}
local rows={}
local searchToken=0
local MAX_ROWS=700
local PROP_SETS={
{"Instance",{"Name","ClassName*","Parent*","Archivable"}},
{"BasePart",{"Position","Orientation","Size","Anchored","CanCollide","CanTouch","CanQuery",
"Transparency","Color","Material*","Reflectance","Massless","CastShadow","Locked"}},
{"Model",{"PrimaryPart*"}},
{"Humanoid",{"Health","MaxHealth","WalkSpeed","JumpPower","JumpHeight","HipHeight","DisplayName"}},
{"GuiObject",{"Visible","Position","Size","AnchorPoint","BackgroundColor3","BackgroundTransparency","ZIndex","LayoutOrder"}},
{"TextLabel",{"Text","TextSize","TextColor3","TextTransparency"}},
{"TextButton",{"Text","TextSize","TextColor3","TextTransparency"}},
{"TextBox",{"Text","TextSize","TextColor3","PlaceholderText"}},
{"ScreenGui",{"Enabled","DisplayOrder","ResetOnSpawn"}},
{"Sound",{"SoundId","Volume","Playing","Looped","TimePosition","PlaybackSpeed"}},
{"Light",{"Brightness","Range","Color","Enabled","Shadows"}},
{"ValueBase",{"Value"}},
{"LuaSourceContainer",{"Disabled"}},
{"Camera",{"FieldOfView","CameraType*","CFrame"}},
{"Lighting",{"Brightness","ClockTime","Ambient","OutdoorAmbient","FogStart","FogEnd","FogColor","GlobalShadows"}},
{"Workspace",{"Gravity","FallenPartsDestroyHeight"}},
{"Decal",{"Texture","Transparency"}},
{"Player",{"UserId*","DisplayName*","Team*","AccountAge*"}},
}
local function esc(s)
s=s:gsub("&","&amp;")
s=s:gsub("<","&lt;")
s=s:gsub(">","&gt;")
return s
end
local function fmt(v)
local t=typeof(v)
if t=="Vector3" then
return string.format("%.2f, %.2f, %.2f",v.X,v.Y,v.Z)
elseif t=="Vector2" then
return string.format("%.2f, %.2f",v.X,v.Y)
elseif t=="Color3" then
return string.format("%d, %d, %d",math.floor(v.R*255+0.5),math.floor(v.G*255+0.5),math.floor(v.B*255+0.5))
elseif t=="UDim2" then
return string.format("{%.2f, %d}, {%.2f, %d}",v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset)
elseif t=="CFrame" then
local p=v.Position
return string.format("%.1f, %.1f, %.1f",p.X,p.Y,p.Z)
elseif t=="number" then
return tostring(math.floor(v*1000+0.5)/1000)
elseif t=="Instance" then
return v:GetFullName()
end
return tostring(v)
end
local function parse(text,sample)
local t=typeof(sample)
if t=="string" then
return text
elseif t=="number" then
return tonumber(text)
elseif t=="Vector3" then
local a,b,c=string.match(text,"^%s*([%-%d%.eE]+)%s*,%s*([%-%d%.eE]+)%s*,%s*([%-%d%.eE]+)%s*$")
if a and tonumber(a)and tonumber(b)and tonumber(c)then
return Vector3.new(tonumber(a),tonumber(b),tonumber(c))
end
elseif t=="Vector2" then
local a,b=string.match(text,"^%s*([%-%d%.eE]+)%s*,%s*([%-%d%.eE]+)%s*$")
if a and tonumber(a)and tonumber(b)then return Vector2.new(tonumber(a),tonumber(b))end
elseif t=="Color3" then
local a,b,c=string.match(text,"^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
if a then
return Color3.fromRGB(math.clamp(tonumber(a),0,255),math.clamp(tonumber(b),0,255),math.clamp(tonumber(c),0,255))
end
end
return nil
end
local function classColor(inst)
if inst:IsA("BasePart")then return Color3.fromRGB(90,170,255)end
if inst:IsA("Model")or inst:IsA("Folder")then return C.Yellow end
if inst:IsA("LuaSourceContainer")then return C.Green end
if inst:IsA("GuiObject")or inst:IsA("LayerCollector")then return Color3.fromRGB(255,120,200)end
if inst:IsA("Humanoid")then return C.Red end
return C.Muted
end
local buildTree,selectInstance,showProps
showProps=function(inst)
for _,ch in ipairs(propList:GetChildren())do
if ch:IsA("Frame")then ch:Destroy()end
end
if not inst then return end
local order=0
local function addRow(name,getValue,setValue)
local ok,value=pcall(getValue)
if not ok then return end
order+=1
local row=new("Frame",{
Size=UDim2.new(1,0,0,26),BorderSizePixel=0,LayoutOrder=order,
BackgroundColor3=C.Panel2,BackgroundTransparency=(order%2==0)and 0.55 or 0.8,
},propList)
corner(row,6)
local nl=label(row,name,UDim2.new(0.42,-6,1,0),UDim2.new(0,8,0,0),11,C.Muted,Enum.Font.GothamMedium)
nl.TextWrapped=false
nl.TextTruncate=Enum.TextTruncate.AtEnd
local t=typeof(value)
local editable=setValue~=nil and(t=="string" or t=="number" or t=="boolean"
or t=="Vector3" or t=="Vector2" or t=="Color3")
local box=new("TextBox",{
BackgroundTransparency=1,Size=UDim2.new(0.58,-8,1,0),Position=UDim2.new(0.42,0,0,0),
Text=fmt(value),TextColor3=editable and C.Text or C.Muted,Font=Enum.Font.GothamMedium,
TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,
TextTruncate=Enum.TextTruncate.AtEnd,TextEditable=editable and t~="boolean",
},row)
if t=="Color3" then
local sw=new("Frame",{
Size=UDim2.fromOffset(12,12),Position=UDim2.new(1,-18,0.5,-6),
BackgroundColor3=value,BorderSizePixel=0,
},row)
corner(sw,3)
box.Size=UDim2.new(0.58,-26,1,0)
end
if editable and t=="boolean" then
box.InputBegan:Connect(function(input)
if input.UserInputType==Enum.UserInputType.MouseButton1
or input.UserInputType==Enum.UserInputType.Touch then
local ok2,cur=pcall(getValue)
if ok2 then
pcall(setValue,not cur)
local ok3,nv=pcall(getValue)
if ok3 then box.Text=fmt(nv)end
end
end
end)
elseif editable then
box.FocusLost:Connect(function(enter)
if enter then
local newV=parse(box.Text,value)
if newV==nil then
notify("Explorer","Invalid value for " .. name,C.Red)
elseif not pcall(setValue,newV)then
notify("Explorer","Could not set " .. name,C.Red)
end
end
local ok3,cur=pcall(getValue)
if ok3 then
value=cur
box.Text=fmt(cur)
end
if enter and name=="Name" then buildTree()end
end)
end
end
for _,set in ipairs(PROP_SETS)do
if inst:IsA(set[1])then
for _,p in ipairs(set[2])do
local ro=string.sub(p,-1)=="*"
local prop=ro and string.sub(p,1,-2)or p
addRow(prop,function()return inst[prop]end,
(not ro)and function(v)inst[prop]=v end or nil)
end
end
end
for k,v in pairs(inst:GetAttributes())do
addRow("@" .. k,function()return v end,nil)
end
end
selectInstance=function(inst)
local prev=rows[selected]
if prev then prev.BackgroundTransparency=1 end
selected=inst
local btn=rows[inst]
if btn then btn.BackgroundTransparency=0.25 end
pathBox.Text=inst and inst:GetFullName()or ""
showProps(inst)
end
local function clearRows()
for _,ch in ipairs(treeScroll:GetChildren())do
if ch:IsA("Frame")then ch:Destroy()end
end
table.clear(rows)
end
local function makeNameButton(row,inst,x)
local btn=new("TextButton",{
Text=esc(inst.Name).. '  <font color="#8e94b4">' .. inst.ClassName .. "</font>",RichText=true,
Size=UDim2.new(1,-x,1,0),Position=UDim2.fromOffset(x,0),
BackgroundColor3=C.Hover,BackgroundTransparency=(inst==selected)and 0.25 or 1,
TextColor3=C.Text,Font=Enum.Font.GothamMedium,TextSize=12,
TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,AutoButtonColor=false,
},row)
corner(btn,5)
rows[inst]=btn
btn.MouseButton1Click:Connect(function()selectInstance(inst)end)
return btn
end
buildTree=function()
local keep=treeScroll.CanvasPosition
clearRows()
local count=0
local function addRow(inst,depth)
if count>=MAX_ROWS then return end
count+=1
local kids=inst:GetChildren()
local row=new("Frame",{
Name="Row",Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=count,
},treeScroll)
local indent=depth*14
if#kids>0 then
local arrow=new("TextButton",{
Text=expanded[inst]and "▾" or "▸",Size=UDim2.fromOffset(16,22),
Position=UDim2.fromOffset(indent,0),BackgroundTransparency=1,TextColor3=C.Muted,
Font=Enum.Font.GothamBold,TextSize=12,AutoButtonColor=false,
},row)
arrow.MouseButton1Click:Connect(function()
expanded[inst]=not expanded[inst]
buildTree()
end)
end
local dot=new("Frame",{
Size=UDim2.fromOffset(6,6),Position=UDim2.fromOffset(indent+18,8),
BackgroundColor3=classColor(inst),BorderSizePixel=0,
},row)
corner(dot,3)
makeNameButton(row,inst,indent+28)
if expanded[inst]and#kids>0 then
table.sort(kids,function(a,b)return string.lower(a.Name)<string.lower(b.Name)end)
for i,child in ipairs(kids)do
if i>300 then
count+=1
local more=new("Frame",{Name="Row",Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=count},treeScroll)
label(more,"… " ..(#kids - 300).. " more (use search)",UDim2.new(1,-indent - 40,1,0),UDim2.fromOffset(indent+28,0),11,C.Muted)
break
end
addRow(child,depth+1)
end
end
end
addRow(game,0)
treeScroll.CanvasPosition=keep
end
local function doSearch(q)
searchToken+=1
local token=searchToken
if q=="" then
buildTree()
return
end
q=string.lower(q)
local found,scanned={},0
for _,inst in ipairs(game:GetDescendants())do
scanned+=1
if scanned%4000==0 then
task.wait()
if token~=searchToken or not exWin or not exWin.Parent then return end
end
if string.find(string.lower(inst.Name),q,1,true)then
table.insert(found,inst)
if#found>=200 then break end
end
end
if token~=searchToken then return end
clearRows()
for i,inst in ipairs(found)do
local row=new("Frame",{
Name="Row",Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=i,
},treeScroll)
local dot=new("Frame",{
Size=UDim2.fromOffset(6,6),Position=UDim2.fromOffset(6,8),
BackgroundColor3=classColor(inst),BorderSizePixel=0,
},row)
corner(dot,3)
makeNameButton(row,inst,18)
end
if#found==0 then
local row=new("Frame",{Name="Row",Size=UDim2.new(1,0,0,22),BackgroundTransparency=1},treeScroll)
label(row,"No matches.",UDim2.new(1,-12,1,0),UDim2.fromOffset(8,0),11,C.Muted)
end
end
local function reveal(inst)
if not inst then return end
local p=inst.Parent
while p and p~=game do
expanded[p]=true
p=p.Parent
end
expanded[game]=true
searchToken+=1
searchBox.Text=""
buildTree()
selectInstance(inst)
local btn=rows[inst]
if btn then
local y=btn.Parent.AbsolutePosition.Y - treeScroll.AbsolutePosition.Y+treeScroll.CanvasPosition.Y
treeScroll.CanvasPosition=Vector2.new(0,math.max(y - 60,0))
end
end
local function buildWindow()
local vpS=cam()and cam().ViewportSize or Vector2.new(1280,720)
local w=math.clamp(vpS.X - 30,360,760)
local h=math.clamp(vpS.Y - 30,340,500)
ui.exSize=UDim2.fromOffset(w,h)
exWin=new("Frame",{
Name="HyperdExplorer",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=ui.exSize,BackgroundColor3=WHITE,ClipsDescendants=true,Visible=false,
},gui)
ui.exWin=exWin
corner(exWin,14)
new("UIGradient",{
Color=ColorSequence.new(Color3.fromRGB(18,14,36),Color3.fromRGB(8,9,18)),Rotation=125,
},exWin)
local st=stroke(exWin,WHITE,2,0)
local sg=new("UIGradient",{},st)
ui.exGrad=sg
onAccent(function()sg.Color=ColorSequence.new(C.A,C.B)end)
local bar=new("Frame",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,Active=true},exWin)
local title=label(bar,"🔎  DEX EXPLORER",UDim2.new(1,-60,1,0),UDim2.new(0,14,0,0),14,WHITE,Enum.Font.GothamBlack)
accentGradient(title,0)
local closeX=button(bar,"✕",UDim2.fromOffset(28,26),UDim2.new(1,-38,0,7))
closeX.MouseButton1Click:Connect(function()ui.openExplorer(false)end)
makeDraggable(bar,exWin)
new("Frame",{
BackgroundColor3=C.Line,BackgroundTransparency=0.5,Size=UDim2.new(1,0,0,1),
Position=UDim2.new(0,0,0,40),BorderSizePixel=0,
},exWin)
local left=new("Frame",{
BackgroundTransparency=1,Position=UDim2.new(0,10,0,48),Size=UDim2.new(0.46,-14,1,-142),
},exWin)
searchBox=textbox(left,"Search by name, press Enter...",UDim2.new(1,0,0,30))
searchBox.FocusLost:Connect(function(enter)
if enter then task.spawn(doSearch,searchBox.Text)end
end)
treeScroll=new("ScrollingFrame",{
Position=UDim2.new(0,0,0,36),Size=UDim2.new(1,0,1,-36),
BackgroundColor3=C.BG,BackgroundTransparency=0.35,BorderSizePixel=0,
ScrollBarThickness=3,ScrollBarImageColor3=C.A,
AutomaticCanvasSize=Enum.AutomaticSize.XY,CanvasSize=UDim2.new(),
},left)
onAccent(function()treeScroll.ScrollBarImageColor3=C.A end)
corner(treeScroll,9)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},treeScroll)
new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,6)},treeScroll)
local right=new("Frame",{
BackgroundTransparency=1,Position=UDim2.new(0.46,4,0,48),Size=UDim2.new(0.54,-14,1,-142),
},exWin)
label(right,"PROPERTIES",UDim2.new(1,0,0,24),UDim2.new(0,2,0,3),11,C.Muted,Enum.Font.GothamBold)
propList=new("ScrollingFrame",{
Position=UDim2.new(0,0,0,36),Size=UDim2.new(1,0,1,-36),
BackgroundColor3=C.BG,BackgroundTransparency=0.35,BorderSizePixel=0,
ScrollBarThickness=3,ScrollBarImageColor3=C.A,
AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
},right)
onAccent(function()propList.ScrollBarImageColor3=C.A end)
corner(propList,9)
new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},propList)
new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,6),PaddingBottom=UDim.new(0,4)},propList)
local bottom=new("Frame",{
BackgroundTransparency=1,Position=UDim2.new(0,10,1,-86),Size=UDim2.new(1,-20,0,78),
},exWin)
pathBox=textbox(bottom,"Select an instance...",UDim2.new(1,0,0,30))
pathBox.TextEditable=false
pathBox.TextColor3=C.Muted
local function actionBtn(i,text)
local b=button(bottom,text,UDim2.new(0.2,-4,0,32),UDim2.new((i - 1)*0.2,0,0,40),i~=4)
b.TextSize=11
return b
end
actionBtn(1,"REVEAL").MouseButton1Click:Connect(function()reveal(selected)end)
actionBtn(2,"HIGHLIGHT").MouseButton1Click:Connect(function()
local had=ui.exHighlight and ui.exHighlight.Adornee==selected
if ui.exHighlight then ui.exHighlight:Destroy();ui.exHighlight=nil end
if had then return end
if selected and(selected:IsA("BasePart")or selected:IsA("Model"))then
ui.exHighlight=new("Highlight",{
Adornee=selected,FillColor=C.A,OutlineColor=WHITE,FillTransparency=0.5,
DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
},workspace.CurrentCamera or workspace)
else
notify("Explorer","Select a part or model first.",C.Red)
end
end)
actionBtn(3,"TELEPORT").MouseButton1Click:Connect(function()
local r=rootPart()
if selected and selected:IsA("PVInstance")and r then
r.CFrame=selected:GetPivot()+Vector3.new(0,5,0)
else
notify("Explorer","Select a part or model first.",C.Red)
end
end)
destroyBtn=actionBtn(4,"DESTROY")
local confirmUntil=0
destroyBtn.MouseButton1Click:Connect(function()
if not selected then
notify("Explorer","Select something first.",C.Red)
return
end
if os.clock()<confirmUntil then
confirmUntil=0
destroyBtn.Text="DESTROY"
local target=selected
selected=nil
if pcall(function()target:Destroy()end)then
pathBox.Text=""
showProps(nil)
buildTree()
notify("Explorer","Destroyed locally.",C.Green)
else
selected=target
notify("Explorer","That instance can't be destroyed.",C.Red)
end
else
confirmUntil=os.clock()+2
destroyBtn.Text="SURE?"
task.delay(2,function()
if destroyBtn and destroyBtn.Parent and os.clock()>=confirmUntil then destroyBtn.Text="DESTROY" end
end)
end
end)
actionBtn(5,"REFRESH").MouseButton1Click:Connect(function()
buildTree()
showProps(selected)
end)
buildTree()
end
ui.openExplorer=function(force)
if not CAN_EXPLORE then
notify("Explorer","Owner access required.",C.Red)
return
end
if not exWin then buildWindow()end
local want=force
if want==nil then want=not exOpen end
exOpen=want
if want then
exWin.Visible=true
exWin.Size=UDim2.fromOffset(0,0)
tween(exWin,0.32,{Size=ui.exSize},Enum.EasingStyle.Back)
else
tween(exWin,0.18,{Size=UDim2.fromOffset(0,0)})
task.delay(0.2,function()
if exWin and exWin.Parent and not exOpen then exWin.Visible=false end
end)
end
end
end
if pages.Admin and REMOTE then
local ad=pages.Admin
section(ad,"Panel access")
infoCard(ad,82,"Give or remove HYPERD for anyone in this server, or bring a player to you. Every request is verified by the server and only owners can use it. Chat commands: ;give  ;remove  ;bring  ;list")
section(ad,"Bulk actions")
action(ad,"Give everyone","Give HYPERD to every player in this server.",function()REMOTE:FireServer("grantAll")end,"GIVE")
action(ad,"Remove everyone","Remove HYPERD from everyone except owners.",function()REMOTE:FireServer("revokeAll")end,"REMOVE")
action(ad,"Bring everyone","Teleport every other player to you.",function()REMOTE:FireServer("bringAll")end,"BRING")
section(ad,"Players")
local listFrame=new("Frame",{
Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,LayoutOrder=nextOrder(ad),
},ad)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},listFrame)
local function rebuild()
for _,ch in ipairs(listFrame:GetChildren())do
if ch:IsA("Frame")then ch:Destroy()end
end
local order=0
for _,p in ipairs(Players:GetPlayers())do
order+=1
local has=p:GetAttribute("HyperdAccess")==true
local owner=p:GetAttribute("HyperdOwner")==true
local row=new("Frame",{
Size=UDim2.new(1,0,0,54),BackgroundColor3=C.Panel,LayoutOrder=order,
},listFrame)
corner(row,12)
stroke(row,C.Line,1,0.35)
label(row,p.DisplayName,UDim2.new(1,-200,0,22),UDim2.new(0,14,0,8),13,C.Text,Enum.Font.GothamBold)
label(row,"@" .. p.Name ..(owner and "  •  OWNER" or(has and "  •  HAS PANEL" or "")),
UDim2.new(1,-200,0,16),UDim2.new(0,14,0,30),10,has and C.Green or C.Muted,Enum.Font.GothamBold)
if p~=LP then
local bring=button(row,"BRING",UDim2.fromOffset(64,32),UDim2.new(1,-176,0.5,-16))
bring.MouseButton1Click:Connect(function()REMOTE:FireServer("bring",p.UserId)end)
end
if not owner then
local give=button(row,has and "REMOVE" or "GIVE",UDim2.fromOffset(84,32),UDim2.new(1,-98,0.5,-16),not has)
give.MouseButton1Click:Connect(function()
REMOTE:FireServer(has and "revoke" or "grant",p.UserId)
end)
end
end
end
local pending=false
local function rebuildSoon()
if pending then return end
pending=true
task.delay(0.15,function()
pending=false
rebuild()
end)
end
local watched={}
local function watch(p)
if watched[p]then return end
watched[p]=true
connect(p:GetAttributeChangedSignal("HyperdAccess"),rebuildSoon)
connect(p:GetAttributeChangedSignal("HyperdOwner"),rebuildSoon)
end
for _,p in ipairs(Players:GetPlayers())do watch(p)end
connect(Players.PlayerAdded,function(p)watch(p);rebuildSoon()end)
connect(Players.PlayerRemoving,function(p)watched[p]=nil;rebuildSoon()end)
rebuild()
end
do
local GOLD=Color3.fromRGB(255,205,70)
local HGREEN=Color3.fromRGB(60,255,140)
local HRED=Color3.fromRGB(255,60,80)
local RAIN_CHARS="0123456789ABCDEF<>/\\|{}[]#$%&*+=~"
local PRIO_SHORT={"CURSOR","DISTANCE","LOW HP"}
local busy=false
local function isVip()return true end
local function randChar()
local i=math.random(1,#RAIN_CHARS)
return string.sub(RAIN_CHARS,i,i)
end
local function hexRow(n)
local t={}
for i=1,n do t[i]=string.format("%02X",math.random(0,255))end
return table.concat(t," ")
end
local function shake(strength,count)
local base=main.Position
for _=1,count do
main.Position=base+UDim2.fromOffset(math.random(-strength,strength),math.random(-strength,strength))
task.wait(0.03)
end
main.Position=base
end
local function startRain(ov,intensity)
local W,H=fullSize.X,fullSize.Y
local colW,charH=14,14
local cols=math.floor(W/colW)+1
local lines=math.floor(H/charH)+2
local cl,speeds,ys={},{},{}
for i=1,cols do
local lbl=new("TextLabel",{
BackgroundTransparency=1,Size=UDim2.fromOffset(colW,lines*charH),
Position=UDim2.fromOffset((i - 1)*colW,-math.random(0,H)),
Text="",TextColor3=WHITE,Font=Enum.Font.Code,TextSize=13,
TextYAlignment=Enum.TextYAlignment.Top,ZIndex=301,
},ov)
new("UIGradient",{
Rotation=90,
Color=ColorSequence.new({
ColorSequenceKeypoint.new(0,Color3.fromRGB(0,120,60)),
ColorSequenceKeypoint.new(0.85,HGREEN),
ColorSequenceKeypoint.new(1,WHITE),
}),
Transparency=NumberSequence.new({
NumberSequenceKeypoint.new(0,1),
NumberSequenceKeypoint.new(0.4,0.55),
NumberSequenceKeypoint.new(1,0),
}),
},lbl)
cl[i]=lbl
speeds[i]=math.random(180,520)*intensity
ys[i]=lbl.Position.Y.Offset
end
local acc=0
local conn
conn=RunService.RenderStepped:Connect(function(dt)
if not ov.Parent then
conn:Disconnect()
return
end
acc+=dt
local refresh=acc>0.07
if refresh then acc=0 end
for i,lbl in ipairs(cl)do
ys[i]+=speeds[i]*dt
if ys[i]>H then
ys[i]=-lines*charH
speeds[i]=math.random(180,520)*intensity
end
lbl.Position=UDim2.fromOffset((i - 1)*colW,ys[i])
if refresh then
local chars=table.create(lines)
for k=1,lines do chars[k]=randChar()end
lbl.Text=table.concat(chars,"\n")
end
end
end)
table.insert(conns,conn)
end
local function typeLine(parent,y,text,color,speed)
local l=new("TextLabel",{
BackgroundTransparency=1,Size=UDim2.new(1,-24,0,18),Position=UDim2.new(0,12,0,y),
Text="",TextColor3=color or HGREEN,Font=Enum.Font.Code,TextSize=13,
TextXAlignment=Enum.TextXAlignment.Left,
},parent)
for i=1,#text do
if not parent.Parent then return end
l.Text=string.sub(text,1,i).. "█"
task.wait(speed)
end
l.Text=text
end
local digitKeys={
[Enum.KeyCode.Zero]="0",[Enum.KeyCode.One]="1",[Enum.KeyCode.Two]="2",[Enum.KeyCode.Three]="3",
[Enum.KeyCode.Four]="4",[Enum.KeyCode.Five]="5",[Enum.KeyCode.Six]="6",[Enum.KeyCode.Seven]="7",
[Enum.KeyCode.Eight]="8",[Enum.KeyCode.Nine]="9",
[Enum.KeyCode.KeypadZero]="0",[Enum.KeyCode.KeypadOne]="1",[Enum.KeyCode.KeypadTwo]="2",
[Enum.KeyCode.KeypadThree]="3",[Enum.KeyCode.KeypadFour]="4",[Enum.KeyCode.KeypadFive]="5",
[Enum.KeyCode.KeypadSix]="6",[Enum.KeyCode.KeypadSeven]="7",[Enum.KeyCode.KeypadEight]="8",
[Enum.KeyCode.KeypadNine]="9",
}
local function startRain2(parent)
local W,H=fullSize.X,fullSize.Y
local colW,charH=14,14
local cols=math.floor(W/colW)+1
local lines=math.floor(H/charH)+2
local ctl={tint=HGREEN,speed=1,fade=0}
local cl,spd,ys={},{},{}
for i=1,cols do
local lbl=new("TextLabel",{
BackgroundTransparency=1,Size=UDim2.fromOffset(colW,lines*charH),
Position=UDim2.fromOffset((i - 1)*colW,-math.random(0,H)),
Text="",TextColor3=ctl.tint,TextTransparency=1,Font=Enum.Font.Code,TextSize=13,
TextYAlignment=Enum.TextYAlignment.Top,ZIndex=301,
},parent)
new("UIGradient",{
Rotation=90,
Transparency=NumberSequence.new({
NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.4,0.55),NumberSequenceKeypoint.new(1,0),
}),
},lbl)
cl[i]=lbl
spd[i]=math.random(180,520)
ys[i]=lbl.Position.Y.Offset
end
local acc=0
local conn
conn=RunService.RenderStepped:Connect(function(dt)
if not parent.Parent then
conn:Disconnect()
return
end
acc+=dt
local refresh=acc>0.07
if refresh then acc=0 end
for i,lbl in ipairs(cl)do
ys[i]+=spd[i]*ctl.speed*dt
if ys[i]>H then
ys[i]=-lines*charH
spd[i]=math.random(180,520)
end
lbl.Position=UDim2.fromOffset((i - 1)*colW,ys[i])
lbl.TextColor3=ctl.tint
lbl.TextTransparency=1 - ctl.fade
if refresh then
local t={}
for k=1,lines do t[k]=randChar()end
lbl.Text=table.concat(t,"\n")
end
end
end)
table.insert(conns,conn)
return ctl
end
local function hostLine()
local ports={22,80,443,8080,3389,25565}
return string.format("> %d.%d.%d.%d  port %d  [%s]",math.random(10,192),math.random(0,255),
math.random(0,255),math.random(1,254),ports[math.random(1,#ports)],
(math.random()<0.5)and "OPEN" or "FILTERED")
end
local function cutscene(quick)
S.hackResult=nil
local skipped=false
local ov=new("Frame",{
Name="HackOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
ZIndex=300,ClipsDescendants=true,Active=true,BorderSizePixel=0,
},main)
corner(ov,18)
local T0=os.clock()
local function at(t)
while os.clock()- T0<t do
if skipped or not ov.Parent then return false end
task.wait(0.02)
end
return not skipped and ov.Parent~=nil
end
local logLbl=label(ov,"",UDim2.new(0.62,0,0,170),UDim2.new(0,14,0,12),12,HGREEN,Enum.Font.Code)
logLbl.TextYAlignment=Enum.TextYAlignment.Top
logLbl.TextWrapped=false
logLbl.ZIndex=320
local cnt=label(ov,"",UDim2.new(0,190,0,120),UDim2.new(1,-204,0,12),12,HGREEN,Enum.Font.Code)
cnt.TextXAlignment=Enum.TextXAlignment.Right
cnt.TextYAlignment=Enum.TextYAlignment.Top
cnt.TextWrapped=false
cnt.ZIndex=320
local barBack=new("Frame",{
AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-40),Size=UDim2.new(0.6,0,0,8),
BackgroundColor3=Color3.fromRGB(0,50,25),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=320,
},ov)
local barFill=new("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=HGREEN,BorderSizePixel=0,ZIndex=321},barBack)
local barLbl=center(label(ov,"",UDim2.new(1,0,0,16),UDim2.new(0,0,1,-34),11,HGREEN,Enum.Font.Code))
barLbl.ZIndex=320
local big=center(label(ov,"",UDim2.new(1,0,0,60),UDim2.new(0.5,0,0.5,0),34,HGREEN,Enum.Font.GothamBlack))
big.AnchorPoint=Vector2.new(0.5,0.5)
big.TextWrapped=false
big.ZIndex=330
local bigScale=new("UIScale",{Scale=1},big)
local flash=new("Frame",{
Size=UDim2.fromScale(1,1),BackgroundColor3=WHITE,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=440,
},ov)
local crt=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.new(0,0,0,2),
BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=430,
},ov)
local skipBtn=new("TextButton",{
Text="SKIP ▸",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-12,1,-10),
Size=UDim2.fromOffset(76,24),BackgroundColor3=HGREEN,BackgroundTransparency=0.85,
TextColor3=HGREEN,Font=Enum.Font.Code,TextSize=12,AutoButtonColor=false,ZIndex=450,
},ov)
stroke(skipBtn,HGREEN,1,0.4)
skipBtn.MouseButton1Click:Connect(function()skipped=true end)
local skipConn=UIS.InputBegan:Connect(function(input)
if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.Return
or input.KeyCode==Enum.KeyCode.Escape then
skipped=true
end
end)
local lines={}
local function push(t)
table.insert(lines,t)
if#lines>9 then table.remove(lines,1)end
logLbl.Text=table.concat(lines,"\n")
end
local function flashScreen(color,alpha,t)
flash.BackgroundColor3=color
flash.BackgroundTransparency=alpha
tween(flash,t,{BackgroundTransparency=1})
end
local function setBar(pct,text,dur)
barBack.BackgroundTransparency=0.2
tween(barFill,dur or 0.3,{Size=UDim2.new(pct,0,1,0)})
barLbl.Text=text
end
local function glitchBig(text,color,dur)
big.Text=text
big.TextColor3=color
task.spawn(function()
local t0=os.clock()
while os.clock()- t0<dur and ov.Parent do
big.Position=UDim2.new(0.5,math.random(-7,7),0.5,math.random(-4,4))
big.TextTransparency=(math.random()<0.3)and 0.6 or 0
task.wait(0.04)
end
if ov.Parent then
big.Position=UDim2.new(0.5,0,0.5,0)
big.TextTransparency=0
end
end)
end
local rain
local function startRainFade(target,dur)
rain=startRain2(ov)
task.spawn(function()
local t0=os.clock()
while ov.Parent and os.clock()- t0<dur do
rain.fade=target*((os.clock()- t0)/dur)
task.wait()
end
rain.fade=target
end)
end
task.spawn(function()
while ov.Parent do
local rows={}
for i=1,6 do
rows[i]=string.format("%08X  %7.2f",math.random(0,0xFFFFFFF),math.random()*9999)
end
cnt.Text=table.concat(rows,"\n")
task.wait(0.05)
end
end)
local displayName=string.upper(LP.DisplayName)
local ev,total
if quick then
total=2.0
ev={
{0.00,function()
flashScreen(HGREEN,0.5,0.35)
tween(crt,0.2,{Size=UDim2.new(1,0,0,2)})
end},
{0.15,function()
tween(crt,0.15,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1})
startRainFade(0.85,0.5)
push("> HYPERD//ENHANCE  session restored")
setBar(1,"ROOT ACCESS",1.0)
end},
{0.45,function()
rain.speed=2.5
big.Text="ACCESS GRANTED"
bigScale.Scale=2.2
tween(bigScale,0.4,{Scale=1},Enum.EasingStyle.Back)
task.spawn(shake,6,8)
end},
{1.20,function()glitchBig("WELCOME BACK, " .. displayName,WHITE,0.4)end},
{1.50,function()
selectPage("Enhancements")
S.hackResult="done"
tween(ov,0.45,{Position=UDim2.new(0,0,-1,0)})
end},
}
else
total=8.0
ev={
{0.00,function()tween(crt,0.22,{Size=UDim2.new(1,0,0,2)})end},
{0.24,function()
tween(crt,0.2,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1})
flashScreen(WHITE,0.5,0.3)
task.spawn(shake,5,8)
end},
{0.45,function()push("> HYPERD//ENHANCE  boot v3.0")end},
{0.70,function()push("> cpu   " .. hexRow(6))end},
{0.95,function()push("> mem   " .. hexRow(6))end},
{1.20,function()push(string.format("> kernel patch 0x%06X  [ OK ]",math.random(0,0xFFFFFF)))end},
{1.45,function()
startRainFade(0.85,1.2)
push("> uplink established  [ OPEN ]")
setBar(0.3,"SCANNING NETWORK",1.8)
end},
{1.75,function()push(hostLine())end},
{1.95,function()push(hostLine())end},
{2.15,function()push(hostLine())end},
{2.35,function()push(hostLine())end},
{2.55,function()push(hostLine())end},
{2.75,function()push(hostLine())end},
{2.95,function()push(hostLine())end},
{3.15,function()push(hostLine())end},
{3.40,function()
flashScreen(HRED,0.35,0.4)
task.spawn(shake,10,16)
rain.tint=HRED
rain.speed=2.2
glitchBig("!! FIREWALL DETECTED !!",HRED,0.9)
push("[!] intrusion countermeasures ACTIVE")
setBar(0.4,"COUNTERMEASURES",0.4)
end},
{3.90,function()
push(string.format("> spoofing signature 0x%06X",math.random(0,0xFFFFFF)))
setBar(0.75,"BYPASSING FIREWALL",1.2)
end},
{4.20,function()push("> " .. hexRow(8))end},
{4.40,function()push("> " .. hexRow(8))end},
{4.60,function()push("> " .. hexRow(8))end},
{4.80,function()push("> " .. hexRow(8))end},
{5.10,function()
glitchBig("COUNTERMEASURES DEFEATED",GOLD,0.5)
push("[+] firewall bypassed")
setBar(0.92,"BYPASSING FIREWALL",0.3)
end},
{5.50,function()
flashScreen(HGREEN,0.25,0.6)
task.spawn(shake,7,12)
rain.tint=HGREEN
rain.speed=3
big.Text="ACCESS GRANTED"
big.TextColor3=HGREEN
bigScale.Scale=2.6
tween(bigScale,0.5,{Scale=1},Enum.EasingStyle.Back)
setBar(1,"ROOT ACCESS",0.3)
end},
{6.20,function()
big.Text="WELCOME, " .. displayName
big.TextColor3=WHITE
push("> root privileges acquired")
end},
{6.60,function()
push("> loading HYPERD//ENHANCEMENTS ...")
barLbl.Text="LOADING MODULES"
end},
{7.00,function()
glitchBig("ENHANCEMENTS UNLOCKED",HGREEN,0.6)
selectPage("Enhancements")
S.hackResult="done"
end},
{7.50,function()tween(ov,0.45,{Position=UDim2.new(0,0,-1,0)})end},
}
end
local finished=true
for _,e in ipairs(ev)do
if not at(e[1])then
finished=false
break
end
e[2]()
end
if finished then at(total)end
skipConn:Disconnect()
if skipped and ov.Parent then S.hackResult="granted" end
end
local function runHack(quick)
if busy then return end
busy=true
local ok,err=pcall(cutscene,quick)
busy=false
if not ok then
warn("[HYPERD] " .. tostring(err))
S.hackResult="granted"
end
local ov=main:FindFirstChild("HackOverlay")
if ov then ov:Destroy()end
if S.hackResult=="granted" then selectPage("Enhancements")end
if not isVip()then LP:SetAttribute("HyperdVIP",true)end
end
ui.openEnhancements=function()
if S.loading or busy then return end
if S.page=="Enhancements" and not busy then return end
local quick=S.cutsceneSeen==true and CONFIG.CutsceneEveryTime~=true
S.cutsceneSeen=true
task.spawn(runHack,quick)
end
local vipInfo=new("TextLabel",{
Name="VipInfo",AnchorPoint=Vector2.new(0.5,0),BackgroundTransparency=1,Visible=false,
Size=UDim2.fromOffset(220,16),Text="",TextColor3=GOLD,Font=Enum.Font.Code,TextSize=12,
TextStrokeTransparency=0.3,TextStrokeColor3=Color3.new(0,0,0),
},hud)
ui.shotFx=function(from,to)
local len=(to - from).Magnitude
if len<0.5 then return end
local beam=Instance.new("Part")
beam.Anchored=true
beam.CanCollide=false
beam.CanQuery=false
beam.CanTouch=false
beam.Material=Enum.Material.Neon
beam.Color=GOLD
beam.Size=Vector3.new(0.15,0.15,len)
beam.CFrame=CFrame.lookAt(from,to)*CFrame.new(0,0,-len/2)
beam.Parent=workspace
TweenService:Create(beam,TweenInfo.new(0.25),{Transparency=1}):Play()
game:GetService("Debris"):AddItem(beam,0.3)
end
local radar=new("Frame",{
Name="Radar",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,24,1,-24),
Size=UDim2.fromOffset(170,170),BackgroundColor3=Color3.fromRGB(0,8,14),
BackgroundTransparency=0.25,Visible=false,ClipsDescendants=true,
},hud)
corner(radar,1000)
stroke(radar,GOLD,2,0.1)
for _,s in ipairs({0.66,0.33})do
local ring=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=UDim2.fromScale(s,s),BackgroundTransparency=1,
},radar)
corner(ring,1000)
stroke(ring,GOLD,1,0.7)
end
new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=UDim2.new(1,0,0,1),BackgroundColor3=GOLD,BackgroundTransparency=0.8,BorderSizePixel=0,
},radar)
new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=UDim2.new(0,1,1,0),BackgroundColor3=GOLD,BackgroundTransparency=0.8,BorderSizePixel=0,
},radar)
local sweepLine=new("Frame",{
AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=UDim2.fromOffset(85,2),BackgroundColor3=GOLD,BorderSizePixel=0,
},radar)
new("UIGradient",{Transparency=NumberSequence.new(0.1,1)},sweepLine)
local selfDot=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
Size=UDim2.fromOffset(6,6),BackgroundColor3=WHITE,BorderSizePixel=0,
},radar)
corner(selfDot,3)
local radarDots={}
connect(RunService.RenderStepped,function()
local show=flags.VipRadar and isVip()
radar.Visible=show
if not show then return end
local c,my=cam(),rootPart()
if not c or not my then return end
local look=c.CFrame.LookVector
local fwd=Vector3.new(look.X,0,look.Z)
fwd=fwd.Magnitude<0.01 and Vector3.new(0,0,-1)or fwd.Unit
local right=Vector3.new(-fwd.Z,0,fwd.X)
local range,R=150,80
sweepLine.Rotation=(os.clock()*120)%360
for _,plr in ipairs(Players:GetPlayers())do
local dot=radarDots[plr]
local r=plr~=LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
if r then
if not dot then
dot=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(7,7),
BackgroundColor3=HRED,BorderSizePixel=0,
},radar)
corner(dot,4)
radarDots[plr]=dot
end
local rel=r.Position - my.Position
local v=Vector2.new(rel:Dot(right),rel:Dot(fwd))/range*R
if v.Magnitude>R - 4 then v=v.Unit*(R - 4)end
dot.Position=UDim2.new(0.5,v.X,0.5,-v.Y)
dot.BackgroundColor3=(LP.Team and plr.Team==LP.Team)and HGREEN or HRED
elseif dot then
dot:Destroy()
radarDots[plr]=nil
end
end
for plr,dot in pairs(radarDots)do
if not plr.Parent then
dot:Destroy()
radarDots[plr]=nil
end
end
end)
ui.vipStep=function(dt,c,center2)
if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)then
if S.locked then setLocked(nil)end
marker.Visible=false
vipInfo.Visible=false
fovStroke.Thickness=aim.thick
fovStroke.Transparency=0.1
return
end
local camPos=c.CFrame.Position
local function evaluate(plr)
local part,ch=aimCandidate(plr)
if not part then return nil end
local dist=(part.Position - camPos).Magnitude
if dist>vip.range then return nil end
local v,onScreen=c:WorldToViewportPoint(part.Position)
if not onScreen then return nil end
local sp=Vector2.new(v.X,v.Y)
local d=(sp - center2).Magnitude
if d>vip.fov then return nil end
if not flags.VipWalls and not lineOfSight(c,part,ch)then return nil end
local score=d
if vip.priority==2 then
score=dist
elseif vip.priority==3 then
local hum=ch:FindFirstChildOfClass("Humanoid")
score=hum and hum.Health or math.huge
end
return part,score,sp,dist,ch
end
local part,sp,dist,ch
if flags.AimSticky and S.locked then
local p2,_,sp2,d2,ch2=evaluate(S.locked)
if p2 then
part,sp,dist,ch=p2,sp2,d2,ch2
else
setLocked(nil)
end
end
if not part then
local bestScore,bestP=math.huge,nil
for _,plr in ipairs(Players:GetPlayers())do
local p2,score,sp2,d2,ch2=evaluate(plr)
if p2 and score<bestScore then
bestScore,bestP=score,plr
part,sp,dist,ch=p2,sp2,d2,ch2
end
end
setLocked(bestP)
end
if not part then
marker.Visible=false
vipInfo.Visible=false
fovStroke.Thickness=aim.thick
fovStroke.Transparency=0.1
return
end
local aimPos=part.Position
if vip.predict>0 then
aimPos+=part.AssemblyLinearVelocity*(dist/math.max(vip.speed,1))*(vip.predict/100)
end
local k=28 -(vip.smooth/100)*25
local alpha=1 - math.exp(-k*dt)
c.CFrame=c.CFrame:Lerp(CFrame.lookAt(camPos,aimPos),alpha)
fovStroke.Thickness=aim.thick+1
fovStroke.Transparency=0
marker.Visible=flags.AimMarker
if marker.Visible then marker.Position=UDim2.fromOffset(sp.X,sp.Y)end
vipInfo.Visible=flags.VipInfo
if vipInfo.Visible then
local hum=ch:FindFirstChildOfClass("Humanoid")
vipInfo.Text=string.upper(S.locked and S.locked.DisplayName or "?").. "  " ..
(hum and math.floor(hum.Health)or 0).. "HP  " .. math.floor(dist).. "m"
vipInfo.Position=UDim2.fromOffset(sp.X,sp.Y+20)
end
if flags.VipWallShot and REMOTE and S.locked
and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)then
local now=os.clock()
if now -(S.lastWallShot or 0)>=0.28 then
S.lastWallShot=now
REMOTE:FireServer("wallShot",S.locked.UserId)
end
end
end
connect(UIS.InputBegan,function(input,processed)
if processed or not flags.VipBlink or not isVip()then return end
if input.KeyCode~=Enum.KeyCode.Q then return end
local r,c=rootPart(),cam()
if not r or not c then return end
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={LP.Character}
local hit=workspace:Raycast(r.Position,r.CFrame.LookVector*vip.blink,params)
local travel=hit and math.max((hit.Position - r.Position).Magnitude - 2.5,0)or vip.blink
r.CFrame=r.CFrame+r.CFrame.LookVector*travel
local f=c.FieldOfView
c.FieldOfView=f+18
tween(c,0.35,{FieldOfView=f})
end)
local ep2=pages.Enhancements
local function vipOnly(key)
return function(on)
if on and not isVip()then
flags[key]=false
refreshFlag(key)
notify("VIP only","Unlock Enhancements first.",C.Red)
end
end
end
local banner=new("Frame",{
Size=UDim2.new(1,-4,0,78),BackgroundColor3=WHITE,LayoutOrder=nextOrder(ep2),
},ep2)
corner(banner,14)
new("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(0,70,36),Color3.fromRGB(0,150,80)),Rotation=20},banner)
label(banner,"⚡  HYPERD//ENHANCEMENTS",UDim2.new(1,-28,0,30),UDim2.new(0,16,0,12),20,WHITE,Enum.Font.GothamBlack)
local bt=label(banner,"root access  •  no PIN required  •  hacker mode",UDim2.new(1,-28,0,20),UDim2.new(0,16,0,44),11,WHITE)
bt.TextTransparency=0.15
section(ep2,"VIP aimbot")
toggle(ep2,"VIP aimbot","Smoother, predictive lock-on. Hold RMB. Replaces the standard aimbot while on.","VipAimbot",function(on)
if on then
if not isVip()then
flags.VipAimbot=false
refreshFlag("VipAimbot")
notify("VIP only","Unlock Enhancements first.",C.Red)
return
end
S.prevAimColor=aim.color
aim.color=GOLD
else
if aim.color==GOLD then aim.color=S.prevAimColor end
S.prevAimColor=nil
end
applyFovColor()
end)
sliders.vipFov=slider(ep2,"VIP FOV size","Radius of the VIP lock-on circle.",40,900,vip.fov," px",function(v)
vip.fov=v
end)
sliders.vipSmooth=slider(ep2,"Smoothness","Higher = a slower, silkier glide to the target.",0,100,vip.smooth,"%",function(v)
vip.smooth=v
end)
sliders.vipPredict=slider(ep2,"Target prediction","Lead moving targets. 0 = off.",0,100,vip.predict,"%",function(v)
vip.predict=v
end)
sliders.vipSpeed=slider(ep2,"Projectile speed","Used for prediction lead (studs per second).",100,3000,vip.speed,"",function(v)
vip.speed=v
end)
sliders.vipRange=slider(ep2,"Max range","Ignore targets farther than this.",50,2000,vip.range," studs",function(v)
vip.range=v
end)
toggle(ep2,"Lock through walls","Target players even when they are behind walls.","VipWalls")
local _,prioBtn=action(ep2,"Target priority","Who gets locked first.",function(b)
vip.priority=vip.priority%3+1
b.Text=PRIO_SHORT[vip.priority]
end,PRIO_SHORT[vip.priority])
ui.vipPrioBtn=prioBtn
toggle(ep2,"Target info","Show name, health and distance on the locked target.","VipInfo")
section(ep2,"Wall shot")
toggle(ep2,"Wall shot (hold LMB)","While locked, hold LMB to hit the target through walls. The server checks range and cooldown.",
"VipWallShot",function(on)
if on and(not isVip()or not REMOTE)then
flags.VipWallShot=false
refreshFlag("VipWallShot")
notify("Unavailable","Needs VIP access and the server link.",C.Red)
end
end)
section(ep2,"VIP utilities")
toggle(ep2,"Radar","Mini-radar showing nearby players.","VipRadar",vipOnly("VipRadar"))
toggle(ep2,"Blink dash (Q)","Press Q to dash forward, stopping at walls.","VipBlink",vipOnly("VipBlink"))
sliders.vipBlink=slider(ep2,"Blink distance","How far Q dashes.",10,80,vip.blink," studs",function(v)
vip.blink=v
end)
action(ep2,"Server heal","Restore your health to full (server side, has a cooldown).",function()
if REMOTE and isVip()then REMOTE:FireServer("vipHeal")end
end,"HEAL")
section(ep2,"Command terminal")
local termCard=card(ep2,260)
local out=new("ScrollingFrame",{
Size=UDim2.new(1,-28,1,-64),Position=UDim2.new(0,14,0,12),
BackgroundColor3=Color3.fromRGB(0,10,5),BorderSizePixel=0,ScrollBarThickness=3,
ScrollBarImageColor3=HGREEN,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
},termCard)
corner(out,8)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},out)
new("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingTop=UDim.new(0,6),PaddingRight=UDim.new(0,8)},out)
local inputBox=textbox(termCard,"type a command (help)...",UDim2.new(1,-28,0,32),UDim2.new(0,14,1,-44))
inputBox.Font=Enum.Font.Code
local lineN=0
local function termPrint(text,color)
lineN+=1
new("TextLabel",{
BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
Text=text,TextColor3=color or HGREEN,Font=Enum.Font.Code,TextSize=12,
TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,LayoutOrder=lineN,
},out)
task.spawn(function()
task.wait()
out.CanvasPosition=Vector2.new(0,out.AbsoluteCanvasSize.Y)
end)
end
local function runCommand(text)
text=string.lower(text)
text=string.gsub(text,"^%s+","")
local parts=string.split(text," ")
local cmd,arg=parts[1],parts[2]
local function onOff(v)return v=="on" or v=="1" or v=="true" end
local function flagCmd(flag,name)
if arg==nil then
termPrint(name .. ": " ..(flags[flag]and "ON" or "OFF"))
else
setFlag(flag,onOff(arg))
termPrint(name .. " -> " ..(flags[flag]and "ON" or "OFF"))
end
end
local function numCmd(slid,name,store)
local n=tonumber(arg)
if not n then
termPrint("usage: " .. cmd .. " <number>",HRED)
return
end
sliders[slid].Set(n)
termPrint(name .. " -> " .. tostring(vip[store]))
end
if cmd=="help" then
termPrint("vipaim on|off      toggle the VIP aimbot")
termPrint("fov <n>            VIP FOV radius")
termPrint("smooth <n>         smoothness 0-100")
termPrint("predict <n>        target prediction 0-100")
termPrint("range <n>          max range in studs")
termPrint("walls on|off       lock through walls")
termPrint("wallshot on|off    wall shot (hold LMB)")
termPrint("radar on|off       radar")
termPrint("blink on|off       blink dash (Q)")
termPrint("heal               server heal")
termPrint("whoami             show access level")
termPrint("clear              clear the screen")
elseif cmd=="vipaim" then flagCmd("VipAimbot","vip aimbot")
elseif cmd=="walls" then flagCmd("VipWalls","lock through walls")
elseif cmd=="wallshot" then flagCmd("VipWallShot","wall shot")
elseif cmd=="radar" then flagCmd("VipRadar","radar")
elseif cmd=="blink" then flagCmd("VipBlink","blink dash")
elseif cmd=="fov" then numCmd("vipFov","vip fov","fov")
elseif cmd=="smooth" then numCmd("vipSmooth","smoothness","smooth")
elseif cmd=="predict" then numCmd("vipPredict","prediction","predict")
elseif cmd=="range" then numCmd("vipRange","range","range")
elseif cmd=="heal" then
if REMOTE then REMOTE:FireServer("vipHeal")end
termPrint("heal request sent")
elseif cmd=="whoami" then
termPrint(LP.Name .. "  |  VIP: " ..(isVip()and "YES" or "NO").. "  |  OWNER: " ..(IS_OWNER and "YES" or "NO"))
elseif cmd=="clear" then
for _,ch in ipairs(out:GetChildren())do
if ch:IsA("TextLabel")then ch:Destroy()end
end
lineN=0
elseif cmd~=nil and cmd~="" then
termPrint("unknown command: " .. cmd .. "  (try help)",HRED)
end
end
inputBox.FocusLost:Connect(function(enter)
if not enter then return end
local t=inputBox.Text
inputBox.Text=""
termPrint("> " .. t,Color3.fromRGB(190,255,215))
runCommand(t)
inputBox:CaptureFocus()
end)
termPrint("HYPERD//ENHANCE terminal ready. type 'help'.")
end
do
local up=pages.Utility
if CAN_EXPLORE then
section(up,"Developer tools")
action(up,"Dex Explorer","Open the instance explorer: browse, search, inspect and edit properties locally.",function()
ui.openExplorer()
end,"OPEN")
end
section(up,"Quality of life")
toggle(up,"Anti-AFK","Stop the game from kicking you for idling.","AntiAFK")
connect(LP.Idled,function()
if flags.AntiAFK then
pcall(function()
local vu=game:GetService("VirtualUser")
vu:CaptureController()
vu:ClickButton2(Vector2.new())
end)
end
end)
sliders.zoom=slider(up,"Max camera zoom","How far out the camera can zoom.",10,1000,
math.floor(original.zoom+0.5),"",function(v)
LP.CameraMaxZoomDistance=v
end)
section(up,"Waypoints")
local wpList
local wpCount=0
local function addWaypoint(name,cf)
wpCount+=1
local row=new("Frame",{
Size=UDim2.new(1,0,0,46),BackgroundColor3=C.Panel,LayoutOrder=wpCount,
},wpList)
corner(row,10)
stroke(row,C.Line,1,0.4)
label(row,name,UDim2.new(1,-130,1,0),UDim2.new(0,14,0,0),12,C.Text,Enum.Font.GothamBold)
local go=button(row,"TP",UDim2.fromOffset(60,30),UDim2.new(1,-112,0.5,-15),true)
local del=button(row,"✕",UDim2.fromOffset(32,30),UDim2.new(1,-46,0.5,-15))
go.MouseButton1Click:Connect(function()
local r=rootPart()
if r then r.CFrame=cf else notify("Teleport failed","Character not loaded.",C.Red)end
end)
del.MouseButton1Click:Connect(function()row:Destroy()end)
end
local nameWrap=new("Frame",{
Size=UDim2.new(1,-4,0,38),BackgroundTransparency=1,LayoutOrder=nextOrder(up),
},up)
local nameBox=textbox(nameWrap,"Waypoint name (optional)...",UDim2.fromScale(1,1))
action(up,"Save waypoint","Store your current position.",function()
local r=rootPart()
if not r then
notify("Waypoint failed","Character not loaded.",C.Red)
return
end
local name=nameBox.Text~="" and nameBox.Text or("Spot " ..(wpCount+1))
addWaypoint(name,r.CFrame)
nameBox.Text=""
notify("Waypoint saved",name,C.Green)
end,"SAVE")
action(up,"Clear waypoints","Delete every saved waypoint.",function()
for _,child in ipairs(wpList:GetChildren())do
if child:IsA("Frame")then child:Destroy()end
end
wpCount=0
end,"CLEAR")
wpList=new("Frame",{
Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,LayoutOrder=nextOrder(up),
},up)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},wpList)
end
do
local sp=pages.Settings
section(sp,"Appearance")
local opts={}
for _,p in ipairs(PALETTES)do
table.insert(opts,{pair={p.a,p.b},name=p.name})
end
swatchRow(sp,"Theme",opts,1,function(_,i)
S.palette=i
applyPalette(i)
notify("Theme",PALETTES[i].name,C.A)
end)
sliders.scale=slider(sp,"UI scale","Resize the whole panel.",70,130,100,"%",function(v)
uiScale.Scale=v/100
end)
sliders.opacity=slider(sp,"Panel opacity","Make the window more see-through.",55,100,100,"%",function(v)
main.BackgroundTransparency=(100 - v)/100
end)
toggle(sp,"Background particles","Floating particles inside the panel.","Particles")
toggle(sp,"Cursor glow","A soft glow follows your mouse inside the panel.","MouseGlow")
toggle(sp,"Rainbow border","Cycle the panel border through every color.","RainbowUI")
action(sp,"Panel hotkey","Click, then press any key to rebind (Esc keeps the current key).",function(b)
if S.rebinding then return end
S.rebinding=true
b.Text="..."
local conn
conn=UIS.InputBegan:Connect(function(input)
if input.UserInputType==Enum.UserInputType.Keyboard then
if input.KeyCode~=Enum.KeyCode.Escape then CONFIG.ToggleKey=input.KeyCode end
b.Text=string.upper(CONFIG.ToggleKey.Name)
if ui.footer then ui.footer.Text=CONFIG.ToggleKey.Name .. "  •  toggle" end
conn:Disconnect()
task.delay(0.25,function()S.rebinding=false end)
end
end)
end,string.upper(CONFIG.ToggleKey.Name))
section(sp,"Cleanup")
action(sp,"RESET ALL","Disable every feature and restore common settings.",function()resetAll()end,"RESET")
action(sp,"Restore camera","Restore the original field of view.",function()
if cam()then cam().FieldOfView=original.fov end
sliders.fov.Set(original.fov,true)
end,"RESTORE")
action(sp,"Restore lighting","Restore the original brightness.",function()
Lighting.Brightness=original.brightness
sliders.brightness.Set(original.brightness*10,true)
end,"RESTORE")
ui.unload=function()
resetAll(true)
pcall(function()RunService:UnbindFromRenderStep("HyperdAim")end)
for _,c in ipairs(conns)do pcall(function()c:Disconnect()end)end
if ui.exHighlight then pcall(function()ui.exHighlight:Destroy()end)end
gui:Destroy()
hud:Destroy()
if DELIVERED then script:Destroy()end
end
action(sp,"Unload HYPERD","Remove the panel and all of its effects.",function()ui.unload()end,"UNLOAD")
end
do
local StarterGui=game:GetService("StarterGui")
local GuiService=game:GetService("GuiService")
local CAS=game:GetService("ContextActionService")
local GREEN=Color3.fromRGB(60,255,140)
local M={
spec=0,presetSlot=1,presets={},tintIdx=1,
dash=40,elev=50,fallCap=90,fovLock=math.floor(original.fov+0.5),
espFillT=0.7,espOutT=0,xray=70,fcSpeed=60,zoomFov=25,
sw={running=false,start=0,elapsed=0},
orig={
exposure=Lighting.ExposureCompensation,fogEnd=Lighting.FogEnd,
minZoom=LP.CameraMinZoomDistance,water=workspace.Terrain.WaterTransparency,
},
}
do
local h0=humanoid()
M.orig.hip=h0 and h0.HipHeight or 2
M.orig.slope=h0 and h0.MaxSlopeAngle or 89
end
pcall(function()M.orig.volume=UserSettings():GetService("UserGameSettings").MasterVolume end)
esp.maxDist=5000
for _,k in ipairs({"BHop","AlwaysRun","LockSpeed","LockJump","AutoJump","NoTrip","GhostPlayers","Follow",
"JoinAlerts","ESPTeamColors","HideChat","HidePlayerList","HideBackpack","HideHealth","HideEmotes",
"ShiftLock","FirstPerson","FovLock","BWMode","NightVision","SunRays","DOF","Disco","HideParticles",
"NoGrass","StatsOverlay","LowHPFlash","HideMyChar","Hotkeys","ChatLog","AutoRejoin","NoFall",
"AntiVoid","RespawnPlace","XRay","Freecam","HoldZoom"})do
defaultFlags[k]=false
flags[k]=false
end
do
local ep0=pages.Enhancements
if ep0 then
ep0.BackgroundColor3=Color3.fromRGB(2,12,7)
ep0.BackgroundTransparency=0.15
corner(ep0,10)
stroke(ep0,GREEN,1,0.5)
local pad=ep0:FindFirstChildOfClass("UIPadding")
if pad then
pad.PaddingLeft=UDim.new(0,8)
pad.PaddingTop=UDim.new(0,6)
end
end
end
local function fx(name,class,props)
local o=Lighting:FindFirstChild(name)
if not o then
o=Instance.new(class)
o.Name=name
for k,v in pairs(props or{})do o[k]=v end
o.Parent=Lighting
end
return o
end
local function dropFx(name)
local o=Lighting:FindFirstChild(name)
if o then o:Destroy()end
end
local FX_NAMES={"HyperdContrast","HyperdBW","HyperdNV","HyperdSun","HyperdDOF","HyperdTint"}
local function setCore(typ,hide)
pcall(function()StarterGui:SetCoreGuiEnabled(typ,not hide)end)
end
local function livePlayers()
local list={}
for _,p in ipairs(Players:GetPlayers())do
if p~=LP and p.Character and p.Character:FindFirstChildOfClass("Humanoid")then
table.insert(list,p)
end
end
table.sort(list,function(a,b)return a.Name<b.Name end)
return list
end
local function nearestPlayer()
local me=rootPart()
if not me then return nil end
local best,bd
for _,p in ipairs(Players:GetPlayers())do
local r=p~=LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if r then
local d=(r.Position - me.Position).Magnitude
if not bd or d<bd then best,bd=p,d end
end
end
return best
end
local function gotoPlayer(p)
local me=rootPart()
local r=p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if me and r then
me.CFrame=r.CFrame*CFrame.new(0,0,4)
notify("Teleported",p.DisplayName,C.Green)
else
notify("Teleport failed","No player available.",C.Red)
end
end
local function pick(p)
S.selected=p
if ui.pickBtn then ui.pickBtn.Text=p.DisplayName .. "  ✓" end
notify("Selected",p.DisplayName,C.A)
end
local function spectate(p)
local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if h and cam()then
cam().CameraSubject=h
S.spectating=true
S.selected=p
notify("Spectating",p.DisplayName,C.A)
else
notify("Spectate failed","No player available.",C.Red)
end
end
do
local mp=pages.Movement
section(mp,"Advanced movement")
toggle(mp,"Bunny hop","Hold Space to keep jumping the moment you land.","BHop")
toggle(mp,"Always run","Use your sprint speed all the time.","AlwaysRun",function(on)
local h=humanoid()
if h and not on then h.WalkSpeed=speeds.walk end
end)
toggle(mp,"Lock walk speed","Re-applies your speed if the game keeps changing it.","LockSpeed")
toggle(mp,"Lock jump power","Re-applies your jump power if the game resets it.","LockJump")
toggle(mp,"Auto-jump","Automatically hop over small obstacles.","AutoJump",function(on)
local h=humanoid()
if h then h.AutoJumpEnabled=on end
end)
toggle(mp,"Anti-trip","Stops tripping and ragdoll states.","NoTrip",function(on)
local h=humanoid()
if h then
pcall(function()
h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,not on)
h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,not on)
end)
end
end)
toggle(mp,"Player collisions off","Walk through other players so nobody can block you.","GhostPlayers")
toggle(mp,"Fall speed cap","Limits how fast you can fall to reduce fall damage.","NoFall")
sliders.fallCap=slider(mp,"Fall speed limit","Maximum downward speed while the cap is on.",30,300,M.fallCap,"",function(v)
M.fallCap=v
end)
sliders.hip=slider(mp,"Hip height","Raise or lower your character off the ground.",0,30,
math.floor(M.orig.hip+0.5),"",function(v)
M.hip=v
local h=humanoid()
if h then h.HipHeight=v end
end)
sliders.slope=slider(mp,"Max slope angle","Steepest slope you can walk up.",0,89,
math.floor(M.orig.slope+0.5),"°",function(v)
M.slope=v
local h=humanoid()
if h then h.MaxSlopeAngle=v end
end)
action(mp,"Sit / stand","Toggle sitting.",function()
local h=humanoid()
if h then h.Sit=not h.Sit end
end,"TOGGLE")
sliders.dash=slider(mp,"Dash distance","How far the Dash button moves you.",10,150,M.dash," studs",function(v)
M.dash=v
end)
action(mp,"Dash forward","Move forward instantly.",function()
local r=rootPart()
if r then r.CFrame=r.CFrame+r.CFrame.LookVector*M.dash end
end,"DASH")
sliders.elev=slider(mp,"Elevator distance","How far Up and Down move you.",10,300,M.elev," studs",function(v)
M.elev=v
end)
action(mp,"Elevator up","Move straight up.",function()
local r=rootPart()
if r then r.CFrame=r.CFrame+Vector3.new(0,M.elev,0)end
end,"UP")
action(mp,"Elevator down","Move straight down.",function()
local r=rootPart()
if r then r.CFrame=r.CFrame - Vector3.new(0,M.elev,0)end
end,"DOWN")
action(mp,"Teleport to spawn","Go to the nearest spawn point.",function()
local r=rootPart()
if not r then return end
local best,bd
for _,d in ipairs(workspace:GetDescendants())do
if d:IsA("SpawnLocation")then
local dist=(d.Position - r.Position).Magnitude
if not bd or dist<bd then best,bd=d,dist end
end
end
if best then
r.CFrame=best.CFrame+Vector3.new(0,5,0)
else
notify("Spawn","No spawn point found.",C.Red)
end
end,"GO")
action(mp,"Quick save position","Remember where you are right now.",function()
local r=rootPart()
if r then
M.saved=r.CFrame
notify("Position saved","Use Quick load to return.",C.Green)
end
end,"SAVE")
action(mp,"Quick load position","Return to your saved position.",function()
local r=rootPart()
if r and M.saved then
r.CFrame=M.saved
else
notify("Nothing saved","Press Quick save first.",C.Red)
end
end,"LOAD")
action(mp,"Return to death point","Go back to where you last died.",function()
local r=rootPart()
if r and M.deathCF then
r.CFrame=M.deathCF
else
notify("No death yet","You haven't died this session.",C.Red)
end
end,"GO")
local function setGravity(v)
workspace.Gravity=v
sliders.gravity.Set(v,true)
end
action(mp,"Moon gravity","Float high with low gravity.",function()setGravity(60)end,"MOON")
action(mp,"Heavy gravity","Drop fast with extra gravity.",function()setGravity(400)end,"HEAVY")
action(mp,"Normal gravity","Back to the default.",function()setGravity(original.gravity)end,"RESET")
end
do
local vp2=pages.Visuals
section(vp2,"Camera tools")
sliders.minZoom=slider(vp2,"Min camera zoom","Closest the camera can get to you.",0,50,
math.floor(M.orig.minZoom+0.5),"",function(v)
pcall(function()LP.CameraMinZoomDistance=v end)
end)
toggle(vp2,"Enable shift-lock","Turn on the shift-lock camera switch.","ShiftLock",function(on)
pcall(function()LP.DevEnableMouseLock=on end)
end)
toggle(vp2,"Force first person","Lock the camera in first person.","FirstPerson",function(on)
pcall(function()LP.CameraMode=on and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic end)
end)
sliders.camX=slider(vp2,"Shoulder offset","Slide the camera left or right.",-10,10,0," st",function(v)
M.camX=v
local h=humanoid()
if h then h.CameraOffset=Vector3.new(v,0,0)end
end)
toggle(vp2,"Lock field of view","Keeps your FOV fixed even if the game changes it.","FovLock")
sliders.fovLock=slider(vp2,"Locked FOV","The FOV used while the lock is on.",20,120,M.fovLock,"°",function(v)
M.fovLock=v
end)
action(vp2,"Spectate next","Watch the next player.",function()
local list=livePlayers()
if#list==0 then
notify("Spectate","No other players.",C.Red)
return
end
M.spec=(M.spec%#list)+1
spectate(list[M.spec])
end,"NEXT")
action(vp2,"Spectate previous","Watch the previous player.",function()
local list=livePlayers()
if#list==0 then
notify("Spectate","No other players.",C.Red)
return
end
M.spec=((M.spec - 2)%#list)+1
spectate(list[M.spec])
end,"PREV")
action(vp2,"Spectate random","Watch a random player.",function()
local list=livePlayers()
if#list==0 then
notify("Spectate","No other players.",C.Red)
return
end
spectate(list[math.random(1,#list)])
end,"RANDOM")
section(vp2,"Hide default interface")
toggle(vp2,"Hide chat","Hide the Roblox chat window.","HideChat",function(on)setCore(Enum.CoreGuiType.Chat,on)end)
toggle(vp2,"Hide player list","Hide the leaderboard.","HidePlayerList",function(on)setCore(Enum.CoreGuiType.PlayerList,on)end)
toggle(vp2,"Hide hotbar","Hide the tool hotbar.","HideBackpack",function(on)setCore(Enum.CoreGuiType.Backpack,on)end)
toggle(vp2,"Hide health bar","Hide the default health bar.","HideHealth",function(on)setCore(Enum.CoreGuiType.Health,on)end)
toggle(vp2,"Hide emotes menu","Hide the emotes wheel button.","HideEmotes",function(on)setCore(Enum.CoreGuiType.EmotesMenu,on)end)
section(vp2,"Lighting & filters")
sliders.exposure=slider(vp2,"Exposure","Overall brightness of the camera.",-30,30,
math.floor(M.orig.exposure*10+0.5),function(v)return string.format("%.1f",v/10)end,function(v)
Lighting.ExposureCompensation=v/10
end)
sliders.ambient=slider(vp2,"Ambient light","Brightness of shaded areas.",0,255,
math.floor(original.ambient.R*255+0.5),"",function(v)
Lighting.Ambient=Color3.fromRGB(v,v,v)
Lighting.OutdoorAmbient=Color3.fromRGB(v,v,v)
end)
sliders.fog=slider(vp2,"Fog distance","How far you can see before fog (3000 = nearly none).",20,3000,
math.clamp(math.floor(M.orig.fogEnd),20,3000),"",function(v)
Lighting.FogEnd=v
end)
action(vp2,"Remove fog","Clear all fog.",function()
Lighting.FogEnd=100000
sliders.fog.Set(3000,true)
end,"CLEAR")
sliders.contrast=slider(vp2,"Contrast","Make the picture punchier or flatter.",-100,100,0,"%",function(v)
if v==0 then
dropFx("HyperdContrast")
else
fx("HyperdContrast","ColorCorrectionEffect").Contrast=v/100
end
end)
toggle(vp2,"Black & white","Remove all color.","BWMode",function(on)
if on then
fx("HyperdBW","ColorCorrectionEffect",{Saturation=-1})
else
dropFx("HyperdBW")
end
end)
toggle(vp2,"Night vision","Green-tinted brightened view.","NightVision",function(on)
if on then
fx("HyperdNV","ColorCorrectionEffect",{
TintColor=Color3.fromRGB(120,255,140),Brightness=0.12,Contrast=0.25,Saturation=-0.3,
})
else
dropFx("HyperdNV")
end
end)
toggle(vp2,"Sun rays","Add god rays from the sun.","SunRays",function(on)
if on then
fx("HyperdSun","SunRaysEffect",{Intensity=0.25,Spread=1})
else
dropFx("HyperdSun")
end
end)
toggle(vp2,"Depth of field","Blur things far from the focus point.","DOF",function(on)
if on then
fx("HyperdDOF","DepthOfFieldEffect",{FarIntensity=0.35,FocusDistance=40,InFocusRadius=25,NearIntensity=0.25})
else
dropFx("HyperdDOF")
end
end)
toggle(vp2,"Disco lighting","Cycle the ambient light through every color.","Disco",function(on)
if not on then updateLightingFlags()end
end)
local TINTS={
{"OFF",nil},{"RED",Color3.fromRGB(255,150,150)},{"ORANGE",Color3.fromRGB(255,200,140)},
{"YELLOW",Color3.fromRGB(255,245,150)},{"GREEN",Color3.fromRGB(150,255,170)},
{"BLUE",Color3.fromRGB(150,190,255)},{"PURPLE",Color3.fromRGB(210,160,255)},
}
action(vp2,"Screen tint","Cycle through color filters.",function(b)
M.tintIdx=M.tintIdx%#TINTS+1
local t=TINTS[M.tintIdx]
if t[2]then
fx("HyperdTint","ColorCorrectionEffect").TintColor=t[2]
else
dropFx("HyperdTint")
end
b.Text=t[1]
end,"OFF")
local hiddenFx={}
toggle(vp2,"Hide particles","Turn off smoke, fire and particle effects to see clearly.","HideParticles",function(on)
if on then
for _,d in ipairs(workspace:GetDescendants())do
if(d:IsA("ParticleEmitter")or d:IsA("Smoke")or d:IsA("Fire")or d:IsA("Sparkles"))
and d.Enabled and string.sub(d.Name,1,6)~="Hyperd" then
d.Enabled=false
table.insert(hiddenFx,d)
end
end
else
for _,d in ipairs(hiddenFx)do
if d.Parent then d.Enabled=true end
end
table.clear(hiddenFx)
end
end)
sliders.water=slider(vp2,"Water transparency","See through terrain water.",0,100,
math.floor(M.orig.water*100+0.5),"%",function(v)
workspace.Terrain.WaterTransparency=v/100
end)
toggle(vp2,"Hide terrain grass","Remove 3D grass decoration for clearer ground.","NoGrass",function(on)
pcall(function()workspace.Terrain.Decoration=not on end)
end)
section(vp2,"Overlays")
local statsLbl=new("TextLabel",{
BackgroundTransparency=1,Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(300,60),
TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
Font=Enum.Font.Code,TextSize=13,TextColor3=WHITE,TextStrokeTransparency=0.4,
Text="",Visible=false,
},hud)
M.statsLbl=statsLbl
toggle(vp2,"Stats overlay","FPS, ping, memory, speed and position in the corner.","StatsOverlay")
local lowHp={}
for i,spec in ipairs({
{UDim2.new(1,0,0,90),UDim2.new(0,0,0,0),90},
{UDim2.new(1,0,0,90),UDim2.new(0,0,1,-90),270},
{UDim2.new(0,90,1,0),UDim2.new(0,0,0,0),0},
{UDim2.new(0,90,1,0),UDim2.new(1,-90,0,0),180},
})do
local f=new("Frame",{
Size=spec[1],Position=spec[2],BackgroundColor3=Color3.fromRGB(255,20,40),
BorderSizePixel=0,Visible=false,
},hud)
new("UIGradient",{Rotation=spec[3],Transparency=NumberSequence.new(0.35,1)},f)
lowHp[i]=f
end
M.lowHp=lowHp
toggle(vp2,"Low-health warning","Pulse the screen edges red when your health is low.","LowHPFlash")
toggle(vp2,"Hide my character","Make your own character invisible to you.","HideMyChar")
end
do
local pl=pages.Players
section(pl,"Quick player tools")
action(pl,"Goto nearest player","Teleport next to the closest player.",function()
gotoPlayer(nearestPlayer())
end,"GO")
action(pl,"Goto random player","Teleport next to a random player.",function()
local list=livePlayers()
if#list==0 then
notify("Teleport","No other players.",C.Red)
return
end
gotoPlayer(list[math.random(1,#list)])
end,"GO")
action(pl,"Select nearest player","Pick the closest player as your target.",function()
local p=nearestPlayer()
if p then pick(p)else notify("Select","No other players.",C.Red)end
end,"PICK")
action(pl,"Select random player","Pick a random player as your target.",function()
local list=livePlayers()
if#list==0 then
notify("Select","No other players.",C.Red)
return
end
pick(list[math.random(1,#list)])
end,"PICK")
action(pl,"Look at selected player","Turn your camera toward the target.",function()
local c=cam()
local r=S.selected and S.selected.Character and S.selected.Character:FindFirstChild("HumanoidRootPart")
if c and r then
c.CFrame=CFrame.lookAt(c.CFrame.Position,r.Position)
else
notify("Look at","Select a player first.",C.Red)
end
end,"LOOK")
action(pl,"Player info","Show details about the selected player.",function()
local p=S.selected
if not p then
notify("Player info","Select a player first.",C.Red)
return
end
notify(p.DisplayName,string.format("@%s  •  ID %d  •  %d days old",p.Name,p.UserId,p.AccountAge),C.A)
end,"SHOW")
toggle(pl,"Follow selected player","Your character walks after the selected player.","Follow",function(on)
if not on then
local h=humanoid()
if h then h:Move(Vector3.zero)end
end
end)
toggle(pl,"Join / leave alerts","Get a notification when players come and go.","JoinAlerts")
connect(Players.PlayerAdded,function(p)
if flags.JoinAlerts then notify("Player joined",p.DisplayName,C.Green)end
end)
connect(Players.PlayerRemoving,function(p)
if flags.JoinAlerts then notify("Player left",p.DisplayName,C.Red)end
end)
end
do
local ep=pages.ESP
section(ep,"ESP tuning")
toggle(ep,"Team colors","Color outlines by each player's team.","ESPTeamColors")
sliders.espFill=slider(ep,"Fill transparency","How see-through the outline fill is.",0,100,70,"%",function(v)
M.espFillT=v/100
end)
sliders.espOut=slider(ep,"Outline transparency","How see-through the outline edge is.",0,100,0,"%",function(v)
M.espOutT=v/100
end)
sliders.espDist=slider(ep,"ESP max distance","Hide ESP for players farther than this.",50,5000,5000," st",function(v)
esp.maxDist=v
end)
local espTick=0
connect(RunService.Heartbeat,function(dt)
espTick+=dt
if espTick<0.2 then return end
espTick=0
for p,hl in pairs(highlights)do
if hl.Parent then
hl.FillColor=(flags.ESPTeamColors and p.Team)and p.TeamColor.Color or esp.fill
hl.FillTransparency=M.espFillT
hl.OutlineTransparency=M.espOutT
end
end
end)
end
do
local cp=pages.Character
section(cp,"More character tools")
action(cp,"Jump","Make your character jump once.",function()
local h=humanoid()
if h then h:ChangeState(Enum.HumanoidStateType.Jumping)end
end,"JUMP")
action(cp,"Reset camera","Fix a stuck or broken camera.",function()
local c=cam()
if c then
c.CameraType=Enum.CameraType.Custom
c.FieldOfView=original.fov
local h=humanoid()
if h then c.CameraSubject=h end
end
S.spectating=false
end,"FIX")
action(cp,"Reset in place","Respawn and return to this exact spot.",function()
local r,h=rootPart(),humanoid()
if r and h then
M.deathCF=r.CFrame
M.forceReturn=true
h.Health=0
end
end,"RESET")
local sv2=pages.Server
section(sv2,"Server tools")
action(sv2,"Ping check","Show your current ping to the server.",function()
local ping="--"
pcall(function()ping=tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()))end)
notify("Ping",ping .. " ms",C.A)
end,"CHECK")
action(sv2,"Server uptime","How long this server has been running.",function()
notify("Uptime",fmtTime(workspace.DistributedGameTime),C.A)
end,"SHOW")
action(sv2,"Place link","Show the game's web address.",function()
notify("Place link","roblox.com/games/" .. game.PlaceId,C.A)
end,"SHOW")
action(sv2,"Print server info","Write server details to the Output window.",function()
print(string.format("[HYPERD] place %d  job %s  players %d/%d  uptime %s",
game.PlaceId,game.JobId,#Players:GetPlayers(),Players.MaxPlayers,fmtTime(workspace.DistributedGameTime)))
notify("Server info","Printed to Output.",C.Green)
end,"PRINT")
local ap=pages.Aimbot
section(ap,"Aimbot extras")
action(ap,"Reset aimbot settings","Back to default FOV, strength and thickness.",function()
sliders.aimFov.Set(AIM_DEFAULT.fov)
sliders.aimStrength.Set(AIM_DEFAULT.strength)
sliders.aimThick.Set(AIM_DEFAULT.thick)
end,"RESET")
end
do
local up2=pages.Utility
section(up2,"System tools")
toggle(up2,"Hotkeys","F fly, N noclip, J infinite jump, B bunny hop, V fullbright, K ESP outlines.","Hotkeys")
connect(UIS.InputBegan,function(input,processed)
if processed or not flags.Hotkeys then return end
local k=input.KeyCode
if k==Enum.KeyCode.F then
setFlag("Fly",not flags.Fly)
elseif k==Enum.KeyCode.N then
setFlag("Noclip",not flags.Noclip)
elseif k==Enum.KeyCode.J then
setFlag("InfJump",not flags.InfJump)
elseif k==Enum.KeyCode.B then
setFlag("BHop",not flags.BHop)
elseif k==Enum.KeyCode.V then
setFlag("Fullbright",not flags.Fullbright)
elseif k==Enum.KeyCode.K then
setFlag("ESPOutline",not flags.ESPOutline)
end
end)
local function gameSettings()
local ok,gs=pcall(function()return UserSettings():GetService("UserGameSettings")end)
return ok and gs or nil
end
sliders.masterVol=slider(up2,"Master volume","Overall game volume.",0,100,
math.floor((M.orig.volume or 1)*100+0.5),"%",function(v)
local gs=gameSettings()
if gs then pcall(function()gs.MasterVolume=v/100 end)end
end)
action(up2,"Mute / unmute","Toggle all game sound.",function()
local gs=gameSettings()
if not gs then return end
pcall(function()
if gs.MasterVolume>0 then
M.volBeforeMute=gs.MasterVolume
gs.MasterVolume=0
sliders.masterVol.Set(0,true)
else
gs.MasterVolume=M.volBeforeMute or 1
sliders.masterVol.Set((M.volBeforeMute or 1)*100,true)
end
end)
end,"TOGGLE")
sliders.quality=slider(up2,"Graphics quality","Manual graphics level (1 = lowest, 21 = highest).",1,21,10,"",function(v)
pcall(function()settings().Rendering.QualityLevel=Enum.QualityLevel["Level" .. string.format("%02d",v)]end)
end)
action(up2,"Automatic graphics","Let Roblox pick the graphics quality again.",function()
pcall(function()settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end)
end,"AUTO")
local _,swInfo=infoCard(up2,56,"00:00.0")
M.swInfo=swInfo
swInfo.Font=Enum.Font.Code
swInfo.TextSize=22
swInfo.TextColor3=C.Text
swInfo.TextXAlignment=Enum.TextXAlignment.Center
swInfo.TextYAlignment=Enum.TextYAlignment.Center
action(up2,"Stopwatch start / stop","Time anything you do.",function()
local sw=M.sw
if sw.running then
sw.elapsed+=os.clock()- sw.start
sw.running=false
else
sw.start=os.clock()
sw.running=true
end
end,"START")
action(up2,"Stopwatch reset","Set the stopwatch back to zero.",function()
M.sw.running=false
M.sw.elapsed=0
end,"RESET")
local nf=card(up2,150)
label(nf,"Notes",UDim2.new(1,-28,0,20),UDim2.new(0,14,0,8),13,C.Text,Enum.Font.GothamBold)
local notesBox=new("TextBox",{
Size=UDim2.new(1,-28,1,-44),Position=UDim2.new(0,14,0,32),BackgroundColor3=C.Panel2,
TextColor3=C.Text,Font=Enum.Font.GothamMedium,TextSize=12,MultiLine=true,TextWrapped=true,
TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ClearTextOnFocus=false,
PlaceholderText="Type notes here (kept while you play)...",PlaceholderColor3=C.Muted,Text="",
},nf)
corner(notesBox,9)
new("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingTop=UDim.new(0,8),PaddingRight=UDim.new(0,10)},notesBox)
action(up2,"Copy IDs to notes","Add the place and server IDs to your notes.",function()
notesBox.Text=notesBox.Text .. "\nPlace ID: " .. game.PlaceId .. "\nJob ID: " .. game.JobId
end,"ADD")
toggle(up2,"Chat logger","Record everything players say.","ChatLog")
local chatCard=card(up2,150)
local chatScroll=new("ScrollingFrame",{
Size=UDim2.new(1,-20,1,-20),Position=UDim2.new(0,10,0,10),BackgroundTransparency=1,
BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
},chatCard)
new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)},chatScroll)
local chatN,chatLines=0,{}
local function chatAdd(p,msg)
chatN+=1
local l=new("TextLabel",{
BackgroundTransparency=1,Size=UDim2.new(1,-6,0,0),AutomaticSize=Enum.AutomaticSize.Y,
Text="[" .. os.date("%H:%M").. "] " .. p.DisplayName .. ": " .. msg,TextColor3=C.Text,
Font=Enum.Font.GothamMedium,TextSize=11,TextWrapped=true,
TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=chatN,
},chatScroll)
table.insert(chatLines,l)
if#chatLines>80 then table.remove(chatLines,1):Destroy()end
task.defer(function()chatScroll.CanvasPosition=Vector2.new(0,1e6)end)
end
local function hookChat(p)
connect(p.Chatted,function(msg)
if flags.ChatLog then chatAdd(p,msg)end
end)
end
for _,p in ipairs(Players:GetPlayers())do hookChat(p)end
connect(Players.PlayerAdded,hookChat)
action(up2,"Clear chat log","Delete the recorded chat.",function()
for _,l in ipairs(chatLines)do l:Destroy()end
table.clear(chatLines)
end,"CLEAR")
action(up2,"Clear notifications","Dismiss every notification on screen.",function()
for _,ch in ipairs(notifHolder:GetChildren())do
if ch:IsA("Frame")then ch:Destroy()end
end
end,"CLEAR")
action(up2,"Reset panel position","Put the panel back in the center of the screen.",function()
main.Position=UDim2.fromScale(0.5,0.5)
end,"CENTER")
action(up2,"Screenshot mode","Hide the whole panel for 5 seconds.",function()
notify("Screenshot mode","Hiding for 5 seconds...",C.A)
task.wait(0.4)
gui.Enabled=false
hud.Enabled=false
task.delay(5,function()
if gui.Parent then
gui.Enabled=true
hud.Enabled=true
end
end)
end,"HIDE")
action(up2,"Show my position","Display your exact coordinates.",function()
local r=rootPart()
if r then
local p=r.Position
notify("Position",string.format("%d, %d, %d",math.floor(p.X),math.floor(p.Y),math.floor(p.Z)),C.A)
end
end,"SHOW")
toggle(up2,"Auto-rejoin on disconnect","Rejoin automatically if you get kicked or disconnected.","AutoRejoin")
connect(GuiService.ErrorMessageChanged,function()
if flags.AutoRejoin and GuiService:GetErrorMessage()~="" then
task.wait(3)
pcall(function()TeleportService:Teleport(game.PlaceId,LP)end)
end
end)
local presetBtnLabel="[ SLOT 1 ]"
action(up2,"Preset slot","Choose one of three preset slots.",function(b)
M.presetSlot=M.presetSlot%3+1
b.Text="SLOT " .. M.presetSlot
end,"SLOT 1")
action(up2,"Save preset","Save every toggle and speed into the chosen slot.",function()
local snap={flags={},speeds={},aim={fov=aim.fov,strength=aim.strength}}
for k,v in pairs(flags)do snap.flags[k]=v end
for k,v in pairs(speeds)do snap.speeds[k]=v end
M.presets[M.presetSlot]=snap
notify("Preset saved","Slot " .. M.presetSlot,C.Green)
end,"SAVE")
action(up2,"Load preset","Restore the chosen slot.",function()
local snap=M.presets[M.presetSlot]
if not snap then
notify("Preset","Slot " .. M.presetSlot .. " is empty.",C.Red)
return
end
for k,v in pairs(snap.flags)do
if flags[k]~=v then setFlag(k,v)end
end
for k,v in pairs(snap.speeds)do speeds[k]=v end
sliders.walk.Set(speeds.walk)
sliders.jump.Set(speeds.jump)
sliders.sprint.Set(speeds.sprint)
sliders.fly.Set(speeds.fly)
sliders.aimFov.Set(snap.aim.fov)
sliders.aimStrength.Set(snap.aim.strength)
notify("Preset loaded","Slot " .. M.presetSlot,C.Green)
end,"LOAD")
end
do
local ep2=pages.Enhancements
section(ep2,"Extra enhancements")
toggle(ep2,"Anti-void","Pulls you back to safety if you fall out of the map.","AntiVoid")
toggle(ep2,"Respawn in place","Come back where you died instead of at spawn.","RespawnPlace")
local xrayConn
local function xrayOne(d,on)
if d:IsA("BasePart")and not d:IsA("Terrain")then
local m=d:FindFirstAncestorOfClass("Model")
if m and m:FindFirstChildOfClass("Humanoid")then return end
d.LocalTransparencyModifier=on and(M.xray/100)or 0
end
end
local function xrayScan(on)
task.spawn(function()
local n=0
for _,d in ipairs(workspace:GetDescendants())do
xrayOne(d,on)
n+=1
if n%1500==0 then task.wait()end
end
end)
end
local function setXray(on)
if xrayConn then xrayConn:Disconnect();xrayConn=nil end
xrayScan(on)
if on then xrayConn=workspace.DescendantAdded:Connect(function(d)xrayOne(d,true)end)end
end
toggle(ep2,"X-ray vision","Make walls and objects see-through.","XRay",setXray)
sliders.xray=slider(ep2,"X-ray strength","How see-through objects become.",10,95,M.xray,"%",function(v)
M.xray=v
if flags.XRay then xrayScan(true)end
end)
local fc={yaw=0,pitch=0,pos=Vector3.zero,conn=nil}
local function stopFreecam()
if fc.conn then fc.conn:Disconnect();fc.conn=nil end
pcall(function()CAS:UnbindAction("HyperdFreecam")end)
UIS.MouseBehavior=Enum.MouseBehavior.Default
local c=cam()
if c then
c.CameraType=Enum.CameraType.Custom
local h=humanoid()
if h then c.CameraSubject=h end
end
end
local function startFreecam()
local c=cam()
if not c then return end
stopFreecam()
local look=c.CFrame.LookVector
fc.yaw=math.atan2(-look.X,-look.Z)
fc.pitch=math.asin(math.clamp(look.Y,-1,1))
fc.pos=c.CFrame.Position
c.CameraType=Enum.CameraType.Scriptable
CAS:BindActionAtPriority("HyperdFreecam",function()return Enum.ContextActionResult.Sink end,false,
Enum.ContextActionPriority.High.Value,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.Space,Enum.KeyCode.LeftShift)
fc.conn=RunService.RenderStepped:Connect(function(dt)
local cc=cam()
if not cc or not flags.Freecam then return end
if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)then
UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
local d=UIS:GetMouseDelta()
fc.yaw -=d.X*0.004
fc.pitch=math.clamp(fc.pitch - d.Y*0.004,-1.5,1.5)
else
UIS.MouseBehavior=Enum.MouseBehavior.Default
end
local rot=CFrame.fromOrientation(fc.pitch,fc.yaw,0)
local move=Vector3.zero
if UIS:IsKeyDown(Enum.KeyCode.W)then move+=rot.LookVector end
if UIS:IsKeyDown(Enum.KeyCode.S)then move -=rot.LookVector end
if UIS:IsKeyDown(Enum.KeyCode.D)then move+=rot.RightVector end
if UIS:IsKeyDown(Enum.KeyCode.A)then move -=rot.RightVector end
if UIS:IsKeyDown(Enum.KeyCode.E)or UIS:IsKeyDown(Enum.KeyCode.Space)then move+=Vector3.yAxis end
if UIS:IsKeyDown(Enum.KeyCode.Q)then move -=Vector3.yAxis end
local spd=M.fcSpeed*(UIS:IsKeyDown(Enum.KeyCode.LeftShift)and 3 or 1)
if move.Magnitude>0 then fc.pos+=move.Unit*spd*dt end
cc.CameraType=Enum.CameraType.Scriptable
cc.CFrame=CFrame.new(fc.pos)*rot
end)
end
toggle(ep2,"Freecam","Fly the camera freely. WASD move, Q/E down/up, hold RMB to look, Shift is fast.","Freecam",function(on)
if on then startFreecam()else stopFreecam()end
end)
sliders.fcSpeed=slider(ep2,"Freecam speed","How fast the free camera moves.",10,300,M.fcSpeed,"",function(v)
M.fcSpeed=v
end)
toggle(ep2,"Hold-to-zoom (Z)","Hold Z to zoom the camera in.","HoldZoom")
sliders.zoomFov=slider(ep2,"Zoom FOV","Lower = more zoom.",5,70,M.zoomFov,"°",function(v)
M.zoomFov=v
end)
local zoomPrev
connect(UIS.InputBegan,function(input,processed)
if processed or not flags.HoldZoom or input.KeyCode~=Enum.KeyCode.Z then return end
local c=cam()
if c and not zoomPrev then
zoomPrev=c.FieldOfView
tween(c,0.15,{FieldOfView=M.zoomFov})
end
end)
connect(UIS.InputEnded,function(input)
if input.KeyCode==Enum.KeyCode.Z and zoomPrev then
local c=cam()
if c then tween(c,0.15,{FieldOfView=zoomPrev})end
zoomPrev=nil
end
end)
action(ep2,"Teleport to crosshair","Instantly move to where your camera points.",function()
local c,r=cam(),rootPart()
if not c or not r then return end
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={LP.Character}
local hit=workspace:Raycast(c.CFrame.Position,c.CFrame.LookVector*3000,params)
if hit then
r.CFrame=CFrame.new(hit.Position+Vector3.new(0,3,0))
else
notify("Teleport","Nothing in range.",C.Red)
end
end,"GO")
end
do
local followT,antiVoidT,lastSafe=0,0,nil
connect(RunService.Heartbeat,function(dt)
local h,r=humanoid(),rootPart()
if h and r then
if flags.BHop and UIS:IsKeyDown(Enum.KeyCode.Space)and not UIS:GetFocusedTextBox()
and h.FloorMaterial~=Enum.Material.Air then
h:ChangeState(Enum.HumanoidStateType.Jumping)
end
if flags.AlwaysRun and not S.sprinting and not flags.Fly then
if h.WalkSpeed~=speeds.sprint then h.WalkSpeed=speeds.sprint end
elseif flags.LockSpeed and not S.sprinting and not flags.Fly then
if h.WalkSpeed~=speeds.walk then h.WalkSpeed=speeds.walk end
end
if flags.LockJump then
local want=flags.HighJump and 100 or speeds.jump
if h.JumpPower~=want then
h.UseJumpPower=true
h.JumpPower=want
end
end
if flags.NoFall then
local v=r.AssemblyLinearVelocity
if v.Y<-M.fallCap then r.AssemblyLinearVelocity=Vector3.new(v.X,-M.fallCap,v.Z)end
end
if flags.Follow then
followT+=dt
if followT>0.25 then
followT=0
local t=S.selected and S.selected.Character and S.selected.Character:FindFirstChild("HumanoidRootPart")
if t then h:MoveTo(t.Position)end
end
end
antiVoidT+=dt
if antiVoidT>0.25 then
antiVoidT=0
if h.Health>0 then
if h.FloorMaterial~=Enum.Material.Air then lastSafe=r.CFrame end
if flags.AntiVoid and lastSafe and r.Position.Y<workspace.FallenPartsDestroyHeight+60 then
r.AssemblyLinearVelocity=Vector3.zero
r.CFrame=lastSafe+Vector3.new(0,4,0)
notify("Anti-void","Pulled you back to safety.",GREEN)
end
end
end
end
if flags.Disco then
local c=Color3.fromHSV((os.clock()*0.3)%1,0.7,0.8)
Lighting.Ambient=c
Lighting.OutdoorAmbient=c
end
end)
connect(RunService.Stepped,function()
if not flags.GhostPlayers then return end
for _,p in ipairs(Players:GetPlayers())do
if p~=LP and p.Character then
for _,part in ipairs(p.Character:GetChildren())do
if part:IsA("BasePart")and part.CanCollide then part.CanCollide=false end
end
end
end
end)
local acc,frames,fps=0,0,60
connect(RunService.RenderStepped,function(dt)
frames+=1
acc+=dt
if acc>=0.25 then
fps=math.floor(frames/acc+0.5)
frames,acc=0,0
if flags.StatsOverlay then
local r=rootPart()
local ping="--"
pcall(function()ping=tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()))end)
local speed=r and math.floor(r.AssemblyLinearVelocity.Magnitude+0.5)or 0
local pos=r and string.format("%d, %d, %d",math.floor(r.Position.X),math.floor(r.Position.Y),math.floor(r.Position.Z))or "-"
M.statsLbl.Text=string.format("FPS %d   PING %s ms\nMEM %d MB   SPEED %d st/s\nPOS %s   PLAYERS %d",
fps,ping,math.floor(Stats:GetTotalMemoryUsageMb()),speed,pos,#Players:GetPlayers())
end
end
M.statsLbl.Visible=flags.StatsOverlay
local hum=humanoid()
local low=flags.LowHPFlash and hum and hum.Health>0 and hum.Health/math.max(hum.MaxHealth,1)<0.3
for _,f in ipairs(M.lowHp)do
f.Visible=low and true or false
if low then f.BackgroundTransparency=0.2+0.2*math.sin(os.clock()*6)end
end
local ch=LP.Character
if ch and(flags.HideMyChar or M.hidWasOn)then
for _,d in ipairs(ch:GetDescendants())do
if d:IsA("BasePart")then d.LocalTransparencyModifier=flags.HideMyChar and 1 or 0 end
end
M.hidWasOn=flags.HideMyChar
end
if flags.FovLock and cam()then cam().FieldOfView=M.fovLock end
if S.page=="Utility" and main.Visible then
local sw=M.sw
local t=sw.elapsed+(sw.running and(os.clock()- sw.start)or 0)
M.swInfo.Text=string.format("%02d:%04.1f",math.floor(t/60),t%60)
end
end)
end
do
local function hookChar(ch)
local h=ch:WaitForChild("Humanoid",8)
if not h then return end
h.Died:Connect(function()
local r=ch:FindFirstChild("HumanoidRootPart")
if r then M.deathCF=r.CFrame end
end)
task.wait(0.3)
if M.hip then h.HipHeight=M.hip end
if M.slope then h.MaxSlopeAngle=M.slope end
if M.camX then h.CameraOffset=Vector3.new(M.camX,0,0)end
if flags.AutoJump then h.AutoJumpEnabled=true end
if flags.NoTrip then
pcall(function()
h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
end)
end
end
if LP.Character then task.spawn(hookChar,LP.Character)end
connect(LP.CharacterAdded,function(ch)
task.spawn(hookChar,ch)
if M.deathCF and(flags.RespawnPlace or M.forceReturn)then
local r=ch:WaitForChild("HumanoidRootPart",8)
if r then
task.wait(0.35)
r.CFrame=M.deathCF
end
end
M.forceReturn=false
end)
end
ui.megaReset=function()
M.dash,M.elev,M.fallCap,M.fovLock=40,50,90,math.floor(original.fov+0.5)
M.espFillT,M.espOutT,M.xray,M.fcSpeed,M.zoomFov=0.7,0,70,60,25
M.hip,M.slope,M.camX,M.tintIdx=nil,nil,nil,1
esp.maxDist=5000
local h=humanoid()
if h then
h.HipHeight=M.orig.hip
h.MaxSlopeAngle=M.orig.slope
h.CameraOffset=Vector3.zero
end
Lighting.ExposureCompensation=M.orig.exposure
Lighting.FogEnd=M.orig.fogEnd
for _,n in ipairs(FX_NAMES)do dropFx(n)end
updateLightingFlags()
for _,t in ipairs({Enum.CoreGuiType.Chat,Enum.CoreGuiType.PlayerList,Enum.CoreGuiType.Backpack,
Enum.CoreGuiType.Health,Enum.CoreGuiType.EmotesMenu})do
setCore(t,false)
end
pcall(function()
LP.CameraMinZoomDistance=M.orig.minZoom
LP.CameraMode=Enum.CameraMode.Classic
end)
pcall(function()workspace.Terrain.WaterTransparency=M.orig.water end)
for key,value in pairs({
fallCap=90,hip=M.orig.hip,slope=M.orig.slope,dash=40,elev=50,minZoom=M.orig.minZoom,
camX=0,fovLock=original.fov,exposure=M.orig.exposure*10,ambient=original.ambient.R*255,
fog=3000,contrast=0,water=M.orig.water*100,xray=70,fcSpeed=60,zoomFov=25,
espFill=70,espOut=0,espDist=5000,
})do
if sliders[key]then sliders[key].Set(value,true)end
end
end
end
do
local TextChatService=game:GetService("TextChatService")
local P2={target=1,regen=3,tlSpeed=6,lastHP=nil,dmgT=0,nearT=0,autoT=0}
for k,v in pairs({HealthRegen=false,DamageLog=false,Compass=false,NearbyHUD=false,
AutoSelect=false,TimeLapse=false,AutoWalk=false,KeepTools=true})do
defaultFlags[k]=v
flags[k]=v
end
flags.ServerLock=false
local tp=pages.Tools
section(tp,"Tool giver")
infoCard(tp,92,"Tools are real items handed out by the server. Give one to yourself, equip it from your hotbar and click to use it. The Bat knocks players back and ragdolls them, the Fling Launcher sends the nearest player (or the one under your cursor) flying, and the Freeze Ray holds a player in place.")
local function sendTool(action,name)
if not REMOTE then
notify("Tools","Tools need the server half of this script.",C.Red)
return
end
local uid=nil
if P2.target==2 then
if not S.selected then
notify("Tools","Select a player first (Players tab).",C.Red)
return
end
uid=S.selected.UserId
end
REMOTE:FireServer(action,name,uid)
end
local function cfgSend(key,v)
if REMOTE then REMOTE:FireServer("toolCfg",key,v)end
end
if IS_OWNER then
action(tp,"Give to","Choose who receives tools: you, or the player selected in the Players tab.",function(b)
P2.target=P2.target%2+1
b.Text=P2.target==1 and "ME" or "SELECTED"
end,"ME")
end
for _,spec in ipairs({
{"Bat","Swing at players to knock them back and ragdoll them."},
{"Fling Launcher","Launches the nearest player (or your target) far away."},
{"Freeze Ray","Freezes a player in place for a few seconds."},
{"Teleport Wand","Click anywhere to teleport there."},
{"Speed Coil","Run faster while it is equipped."},
{"Gravity Coil","Jump much higher while it is equipped."},
{"Heal Wand","Heals you and nearby players."},
})do
action(tp,spec[1],spec[2],function()sendTool("toolGive",spec[1])end,"GIVE")
end
action(tp,"Give all tools","Hand out every tool at once.",function()sendTool("toolGive","ALL")end,"GIVE ALL")
action(tp,"Remove all tools","Take every HYPERD tool away.",function()sendTool("toolTake","ALL")end,"REMOVE")
toggle(tp,"Keep tools after respawn","Get your tools back automatically when you respawn.","KeepTools",function(on)
if REMOTE then REMOTE:FireServer("toolKeep",on)end
end)
section(tp,"Tool settings")
sliders.toolKb=slider(tp,"Bat knockback","How hard the bat shoves players.",10,250,80,"",function(v)cfgSend("kb",v)end)
sliders.toolRag=slider(tp,"Ragdoll time","Seconds a hit player stays ragdolled.",1,10,3," s",function(v)cfgSend("rag",v)end)
sliders.toolFling=slider(tp,"Fling power","Launch speed of the Fling Launcher.",40,500,220,"",function(v)cfgSend("fling",v)end)
sliders.toolRange=slider(tp,"Fling range","How far the Fling Launcher can reach.",10,300,90," studs",function(v)cfgSend("range",v)end)
sliders.toolFreeze=slider(tp,"Freeze time","Seconds the Freeze Ray holds a player.",1,15,4," s",function(v)cfgSend("freeze",v)end)
local mouse=LP:GetMouse()
connect(mouse.Button1Down,function()
local ch=LP.Character
local tool=ch and ch:FindFirstChildOfClass("Tool")
if not tool or not tool:GetAttribute("HyperdTool")or not REMOTE then return end
local uid=nil
local tgt=mouse.Target
if tgt then
local m=tgt:FindFirstAncestorOfClass("Model")
local p=m and Players:GetPlayerFromCharacter(m)
if p and p~=LP then uid=p.UserId end
end
REMOTE:FireServer("toolAim",uid,mouse.Hit.Position)
end)
if pages.Admin and REMOTE then
local ad=pages.Admin
section(ad,"Moderation tools")
local annWrap=new("Frame",{Size=UDim2.new(1,-4,0,38),BackgroundTransparency=1,LayoutOrder=nextOrder(ad)},ad)
local ann=textbox(annWrap,"Type an announcement...",UDim2.fromScale(1,1))
action(ad,"Send announcement","Show your message to everyone who has the panel.",function()
if ann.Text~="" then
REMOTE:FireServer("announce",ann.Text)
ann.Text=""
end
end,"SEND")
local function onSelected(act,label2)
return function()
if not S.selected then
notify(label2,"Select a player first (Players tab).",C.Red)
return
end
REMOTE:FireServer(act,S.selected.UserId)
end
end
action(ad,"Kick selected player","Remove the selected player from the server.",onSelected("kick","Kick"),"KICK")
action(ad,"Freeze selected player","Hold the selected player in place until unfrozen.",onSelected("freeze","Freeze"),"FREEZE")
action(ad,"Unfreeze selected player","Let the selected player move again.",onSelected("unfreeze","Unfreeze"),"UNFREEZE")
action(ad,"Heal selected player","Restore the selected player's health.",onSelected("healPlayer","Heal"),"HEAL")
toggle(ad,"Lock server","Kick anyone who tries to join. Owners can still join.","ServerLock",function(on)
REMOTE:FireServer("lockServer",on)
end)
local sureUntil=0
action(ad,"Kick everyone else","Remove every non-owner. Press twice to confirm.",function(b)
if os.clock()<sureUntil then
sureUntil=0
b.Text="KICK ALL"
REMOTE:FireServer("kickAll")
else
sureUntil=os.clock()+3
b.Text="SURE?"
task.delay(3,function()
if b.Parent and os.clock()>=sureUntil then b.Text="KICK ALL" end
end)
end
end,"KICK ALL")
end
local cp=pages.Character
section(cp,"Survival extras")
toggle(cp,"Health regeneration","Slowly heal over time (done on the server).","HealthRegen",function(on)
if REMOTE then REMOTE:FireServer("regen",on and P2.regen or 0)end
end)
sliders.regen=slider(cp,"Regeneration speed","Health per second while regeneration is on.",1,10,P2.regen," hp/s",function(v)
P2.regen=v
if flags.HealthRegen and REMOTE then REMOTE:FireServer("regen",v)end
end)
toggle(cp,"Damage log","Show a notification with how much health you lost.","DamageLog")
action(cp,"Unstuck","Pop up a few studs and clear your speed if you are stuck.",function()
local r,h=rootPart(),humanoid()
if r then
r.CFrame=r.CFrame+Vector3.new(0,6,0)
r.AssemblyLinearVelocity=Vector3.zero
end
if h then
h.Sit=false
h.PlatformStand=false
end
end,"FIX")
local up3=pages.Utility
section(up3,"More utilities")
local compassLbl=new("TextLabel",{
BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,40),
Size=UDim2.fromOffset(200,22),Font=Enum.Font.Code,TextSize=16,TextColor3=WHITE,
TextStrokeTransparency=0.4,Text="",Visible=false,
},hud)
local nearLbl=new("TextLabel",{
BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.4,0),
Size=UDim2.fromOffset(200,110),TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Top,
Font=Enum.Font.Code,TextSize=12,TextColor3=WHITE,TextStrokeTransparency=0.4,Text="",Visible=false,
},hud)
toggle(up3,"Compass","Show which way you are facing at the top of the screen.","Compass")
toggle(up3,"Nearby players","List the five closest players and how far away they are.","NearbyHUD")
toggle(up3,"Auto-select nearest player","Keep the closest player selected as your target.","AutoSelect")
toggle(up3,"Auto-walk forward","Keep walking forward in the camera direction (handy while AFK).","AutoWalk")
toggle(up3,"Time lapse","Make the day and night cycle run on its own.","TimeLapse")
sliders.tlSpeed=slider(up3,"Time lapse speed","Game hours that pass per real minute.",1,24,P2.tlSpeed," h/min",function(v)
P2.tlSpeed=v
end)
action(up3,"Find friends","List friends who are in this server.",function()
local names={}
for _,p in ipairs(Players:GetPlayers())do
if p~=LP then
local ok,isF=pcall(function()return LP:IsFriendsWith(p.UserId)end)
if ok and isF then table.insert(names,p.DisplayName)end
end
end
notify("Friends here",#names>0 and table.concat(names,", ")or "none",C.A)
end,"FIND")
local function say(msg)
local ok=pcall(function()
local channels=TextChatService:FindFirstChild("TextChannels")
local general=channels and channels:FindFirstChild("RBXGeneral")
if not general then error("no channel")end
general:SendAsync(msg)
end)
if not ok then
pcall(function()
game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg,"All")
end)
end
end
action(up3,"Say: gg","Send \"gg\" in chat.",function()say("gg")end,"SAY")
action(up3,"Say: good luck, have fun","Send a friendly message in chat.",function()say("Good luck, have fun!")end,"SAY")
action(up3,"Say: be right back","Send \"brb\" in chat.",function()say("brb")end,"SAY")
action(up3,"Say my coordinates","Send your position in chat.",function()
local r=rootPart()
if r then
local p=r.Position
say(string.format("I'm at %d, %d, %d",math.floor(p.X),math.floor(p.Y),math.floor(p.Z)))
end
end,"SAY")
local DIRS={"N","NE","E","SE","S","SW","W","NW"}
local function nearbyList()
local me=rootPart()
local list={}
if not me then return list end
for _,p in ipairs(Players:GetPlayers())do
local r=p~=LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if r then table.insert(list,{p=p,d=(r.Position - me.Position).Magnitude})end
end
table.sort(list,function(a,b)return a.d<b.d end)
return list
end
connect(RunService.Heartbeat,function(dt)
local h=humanoid()
if flags.AutoWalk and h then h:Move(Vector3.new(0,0,-1),true)end
if flags.TimeLapse then Lighting.ClockTime=(Lighting.ClockTime+dt*P2.tlSpeed/60)%24 end
if h then
local hp=h.Health
if flags.DamageLog and P2.lastHP and hp<P2.lastHP - 0.5 and os.clock()- P2.dmgT>0.4 then
P2.dmgT=os.clock()
notify("Damage","-" .. math.floor(P2.lastHP - hp+0.5).. " HP",C.Red)
end
P2.lastHP=hp
end
P2.nearT+=dt
if P2.nearT>0.4 then
P2.nearT=0
local list=nil
if flags.NearbyHUD or flags.AutoSelect then list=nearbyList()end
if flags.NearbyHUD and list then
local rows={"NEARBY"}
for i=1,math.min(5,#list)do
table.insert(rows,string.format("%s  %d st",list[i].p.DisplayName,math.floor(list[i].d)))
end
nearLbl.Text=table.concat(rows,"\n")
end
if flags.AutoSelect and list and list[1]and S.selected~=list[1].p then
S.selected=list[1].p
if ui.pickBtn then ui.pickBtn.Text=list[1].p.DisplayName .. "  ✓" end
end
end
nearLbl.Visible=flags.NearbyHUD
end)
connect(RunService.RenderStepped,function()
compassLbl.Visible=flags.Compass
if flags.Compass and cam()then
local look=cam().CFrame.LookVector
local heading=math.deg(math.atan2(look.X,-look.Z))%360
local idx=math.floor((heading+22.5)/45)%8+1
compassLbl.Text=string.format("%s   %d°",DIRS[idx],math.floor(heading))
end
end)
ui.packReset=function()
P2.regen,P2.tlSpeed,P2.target=3,6,1
for key,value in pairs({
regen=3,tlSpeed=6,toolKb=80,toolRag=3,toolFling=220,toolRange=90,toolFreeze=4,
})do
if sliders[key]then sliders[key].Set(value,true)end
end
cfgSend("kb",80)
cfgSend("rag",3)
cfgSend("fling",220)
cfgSend("range",90)
cfgSend("freeze",4)
end
end
resetAll=function(silent)
for key,value in pairs(defaultFlags)do setFlag(key,value)end
stopFly()
stopAnimation()
S.sprinting=false
S.spectating=false
local h=humanoid()
if h then
h.PlatformStand=false
h.AutoRotate=true
h.WalkSpeed=original.walkSpeed
h.UseJumpPower=true
h.JumpPower=original.jumpPower
if cam()then cam().CameraSubject=h end
end
local r=rootPart()
if r then r.AssemblyAngularVelocity=Vector3.zero end
for p in pairs(highlights)do clearESP(p)end
for p in pairs(labels)do clearESP(p)end
removeTrail()
setGlow(false)
setBlur(false)
Lighting.Brightness=original.brightness
if cam()then cam().FieldOfView=original.fov end
speeds.walk,speeds.jump,speeds.sprint,speeds.fly=original.walkSpeed,original.jumpPower,26,70
sliders.walk.Set(speeds.walk,true)
sliders.jump.Set(speeds.jump,true)
sliders.sprint.Set(speeds.sprint,true)
sliders.fly.Set(speeds.fly,true)
sliders.fov.Set(original.fov,true)
sliders.brightness.Set(original.brightness*10,true)
if ui.megaReset then ui.megaReset()end
if ui.packReset then ui.packReset()end
workspace.Gravity=original.gravity
Lighting.ClockTime=original.clock
LP.CameraMaxZoomDistance=original.zoom
if S.cc then S.cc:Destroy();S.cc=nil end
if cam()then cam().CameraType=Enum.CameraType.Custom end
sliders.gravity.Set(original.gravity,true)
sliders.time.Set(original.clock,true)
sliders.zoom.Set(original.zoom,true)
sliders.sat.Set(0,true)
xhair.len,xhair.gap=8,4
layoutCrosshair()
sliders.xsize.Set(8,true)
sliders.xgap.Set(4,true)
orbit.speed,orbit.radius,orbit.height=6,14,5
sliders.orbitSpeed.Set(6,true)
sliders.orbitRadius.Set(14,true)
sliders.orbitHeight.Set(5,true)
S.animSpeed=1
sliders.animSpeed.Set(100,true)
vip.fov,vip.smooth,vip.predict,vip.speed,vip.range,vip.priority,vip.blink=260,65,60,900,700,1,35
sliders.vipFov.Set(260,true)
sliders.vipSmooth.Set(65,true)
sliders.vipPredict.Set(60,true)
sliders.vipSpeed.Set(900,true)
sliders.vipRange.Set(700,true)
sliders.vipBlink.Set(35,true)
if ui.vipPrioBtn then ui.vipPrioBtn.Text="CURSOR" end
aim.fov,aim.strength,aim.thick,aim.color=AIM_DEFAULT.fov,AIM_DEFAULT.strength,AIM_DEFAULT.thick,nil
aimPartIndex=1
ui.partBtn.Text=string.upper(AIM_PARTS[1])
fovCircle.Size=UDim2.fromOffset(aim.fov*2,aim.fov*2)
fovStroke.Thickness=aim.thick
sliders.aimFov.Set(aim.fov,true)
sliders.aimStrength.Set(aim.strength,true)
sliders.aimThick.Set(aim.thick,true)
ui.fovSwatch.Select(1)
applyFovColor()
setLocked(nil)
marker.Visible=false
if not silent then
notify("RESET COMPLETE","All features cleared and defaults restored.",C.Green)
end
end
local launcher=new("TextButton",{
Name="Launcher",Text="",AutoButtonColor=false,
Size=UDim2.fromOffset(54,54),Position=UDim2.new(0,18,0.45,0),BackgroundColor3=WHITE,
},gui)
corner(launcher,16)
ui.launcherGrad=accentGradient(launcher,45)
local launcherStroke=stroke(launcher,WHITE,2,0.4)
center(label(launcher,"H",UDim2.fromScale(1,1),nil,28,WHITE,Enum.Font.GothamBlack))
TweenService:Create(launcherStroke,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
{Thickness=5,Transparency=0.85}):Play()
local function playLoading()
S.loading=true
local ov=new("Frame",{
Name="Loading",Size=UDim2.fromScale(1,1),BackgroundColor3=C.BG,ZIndex=200,
},main)
corner(ov,18)
local lg=new("Frame",{
AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,-52),
Size=UDim2.fromOffset(74,74),BackgroundColor3=WHITE,
},ov)
corner(lg,22)
accentGradient(lg,45)
center(label(lg,"H",UDim2.fromScale(1,1),nil,42,WHITE,Enum.Font.GothamBlack))
local ls=new("UIScale",{},lg)
TweenService:Create(ls,TweenInfo.new(0.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
{Scale=1.12}):Play()
local name=center(label(ov,"HYPERD",UDim2.new(1,0,0,34),UDim2.new(0,0,0.5,2),28,WHITE,Enum.Font.GothamBlack))
accentGradient(name,0)
local status=center(label(ov,"Initializing core...",UDim2.new(1,0,0,18),UDim2.new(0,0,0.5,40),11,C.Muted,Enum.Font.GothamBold))
local bar=new("Frame",{
AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,68),
Size=UDim2.fromOffset(240,8),BackgroundColor3=C.Off,
},ov)
corner(bar,4)
local fill=new("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=WHITE},bar)
corner(fill,4)
accentGradient(fill,0)
local pct=center(label(ov,"0%",UDim2.new(1,0,0,16),UDim2.new(0,0,0.5,82),10,C.Muted,Enum.Font.GothamBold))
tween(fill,1.7,{Size=UDim2.fromScale(1,1)},Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
local steps={"Initializing core...","Loading modules...","Calibrating aimbot...","Syncing ESP...","Ready."}
for i,s in ipairs(steps)do
status.Text=s
pct.Text=(i*20).. "%"
task.wait(0.34)
end
if ov.Parent then ov:Destroy()end
S.loading=false
end
local function openPanel()
if S.open or S.loading then return end
S.open=true
main.Visible=true
main.Size=UDim2.fromOffset(0,0)
tween(main,0.32,{Size=S.minimized and miniUDim or fullUDim},Enum.EasingStyle.Back)
if S.firstOpen or CONFIG.LoadingEveryOpen then
S.firstOpen=false
task.spawn(playLoading)
end
end
local function closePanel()
if not S.open or S.loading then return end
S.open=false
tween(main,0.18,{Size=UDim2.fromOffset(0,0)})
task.delay(0.2,function()
if not S.open then main.Visible=false end
end)
end
local function togglePanel()
if S.open then closePanel()else openPanel()end
end
makeDraggable(launcher,launcher,togglePanel)
closeBtn.MouseButton1Click:Connect(closePanel)
minBtn.MouseButton1Click:Connect(function()
if S.loading then return end
S.minimized=not S.minimized
sidebar.Visible=not S.minimized
content.Visible=not S.minimized
tween(main,0.25,{Size=S.minimized and miniUDim or fullUDim},Enum.EasingStyle.Quad)
end)
connect(UIS.InputBegan,function(input,processed)
if processed or S.rebinding then return end
if input.KeyCode==CONFIG.ToggleKey then togglePanel()end
end)
do
local accum,frames=0,0
connect(RunService.RenderStepped,function(dt)
if main.Visible then
mainStrokeGrad.Rotation=(mainStrokeGrad.Rotation+dt*50)%360
end
if fovCircle.Visible then
fovStrokeGrad.Rotation=(fovStrokeGrad.Rotation+dt*40)%360
end
if main.Visible then
titleGrad.Rotation=(titleGrad.Rotation+dt*35)%360
if ui.bannerGrad then ui.bannerGrad.Rotation=(ui.bannerGrad.Rotation+dt*12)%360 end
end
if ui.launcherGrad then ui.launcherGrad.Rotation=(ui.launcherGrad.Rotation+dt*60)%360 end
if S.rainbow then
local t=os.clock()*0.3
S.rainbow.FillColor=Color3.fromHSV(t%1,1,1)
S.rainbow.OutlineColor=Color3.fromHSV((t+0.5)%1,1,1)
end
if main.Visible then
if flags.MouseGlow then
local m=UIS:GetMouseLocation()
local sc=uiScale.Scale
local tx=(m.X - main.AbsolutePosition.X)/sc
local ty=(m.Y - main.AbsolutePosition.Y)/sc
local cur=mouseGlow.Position
local k=math.min(dt*8,1)
mouseGlow.Visible=true
mouseGlow.Position=UDim2.fromOffset(
cur.X.Offset+(tx - cur.X.Offset)*k,
cur.Y.Offset+(ty - cur.Y.Offset)*k)
else
mouseGlow.Visible=false
end
if flags.RainbowUI then
local t=os.clock()*0.25
mainStrokeGrad.Color=ColorSequence.new({
ColorSequenceKeypoint.new(0,Color3.fromHSV(t%1,0.8,1)),
ColorSequenceKeypoint.new(0.5,Color3.fromHSV((t+0.33)%1,0.8,1)),
ColorSequenceKeypoint.new(1,Color3.fromHSV((t+0.66)%1,0.8,1)),
})
S.rainbowUI=true
elseif S.rainbowUI then
S.rainbowUI=false
applyPalette(S.palette or 1)
end
end
if ui.exGrad and ui.exWin and ui.exWin.Visible then
ui.exGrad.Rotation=(ui.exGrad.Rotation+dt*50)%360
end
updateTracers()
orbitStep(dt)
frames+=1
accum+=dt
if accum<0.5 then return end
local fps=math.floor(frames/accum+0.5)
frames,accum=0,0
if not main.Visible then return end
local ping="--"
pcall(function()
ping=tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()))
end)
if statPill then statPill.Text=fps .. " FPS  •  " .. ping .. " ms" end
ui.stat.fps.Text=tostring(fps)
ui.stat.ping.Text=ping .. " ms"
ui.stat.players.Text=#Players:GetPlayers().. "/" .. Players.MaxPlayers
ui.stat.uptime.Text=fmtTime(workspace.DistributedGameTime)
if ui.pushFps then ui.pushFps(fps)end
for _,fn in ipairs(liveUpdaters)do pcall(fn)end
end)
end
connect(LP.CharacterAdded,function(ch)
stopFly()
setFlag("Fly",false)
S.sprinting=false
local h=ch:WaitForChild("Humanoid",10)
task.wait(0.5)
h=humanoid()
if h then
h.WalkSpeed=speeds.walk
applyJump()
end
if flags.Glow then setGlow(true)end
if flags.Trail then setTrail(true)end
if flags.Rainbow then setRainbow(true)end
if flags.Aura then setAura(true)end
if cam()and S.spectating then S.spectating=false end
end)
if DELIVERED then
if REMOTE then
connect(REMOTE.OnClientEvent,function(kind,a,b,c)
if kind=="notify" then
notify(tostring(a),tostring(b),c=="good" and C.Green or(c=="bad" and C.Red or C.A))
elseif kind=="vipResult" then
S.vipResult={ok=(a==true),info=b}
elseif kind=="shotFx" and typeof(a)=="Vector3" and typeof(b)=="Vector3" and ui.shotFx then
ui.shotFx(a,b)
end
end)
end
connect(LP:GetAttributeChangedSignal("HyperdAccess"),function()
if LP:GetAttribute("HyperdAccess")~=true then
notify("HYPERD","Your panel access was removed.",C.Red)
task.wait(1.2)
ui.unload()
end
end)
end
selectPage("Dashboard")
notify("HYPERD READY","Press " .. CONFIG.ToggleKey.Name .. " or tap the H button.",C.Green)
print("[HYPERD] v4.0 loaded.")
