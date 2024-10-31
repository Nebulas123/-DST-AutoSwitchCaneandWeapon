local CacheService = require "util/cacheservice"
local Autoswitch = Class(function(self, inst)
    self.inst = inst
    self.chipSlot = 15
    self.isSpinning = false
    self.weaponList = {}
    self.toolList = {}
end)

function Autoswitch:SetWeaponList(weaponList) self.weaponList = weaponList end

function Autoswitch:SetWeaponList(toolList) self.toolList = toolList end

function Autoswitch:IsInGame()
    return ThePlayer ~= nil and TheFrontEnd:GetActiveScreen().name == "HUD"
end

function Autoswitch:SetchipSlot(num) self.chipSlot = num end

function Autoswitch:SwitchSpinning()
    if not Autoswitch:IsInGame() then return end
    if self.isSpinning then
        ChatHistory:SendCommandResponse('自动切手杖:关闭')
        self.inst:StopUpdatingComponent(self)
        self.isSpinning = false
        self:IconHide()
    else
        ChatHistory:SendCommandResponse('自动切手杖:启动')
        self.inst:StartUpdatingComponent(self)
        self.isSpinning = true
        self:IconHint()
    end
end

function Autoswitch:IconHint()
    if ThePlayer and ThePlayer.HUD and ThePlayer.HUD.controls and
        ThePlayer.HUD.controls.inv and ThePlayer.HUD.controls.inv.inv and
        ThePlayer.HUD.controls.inv.inv[self.chipSlot] then
        ThePlayer.HUD.controls.inv.inv[self.chipSlot]:SetBGImage2(
            "images/icon-autoswitch-hint.xml", "icon-autoswitch-hint.tex")
    end
    if ThePlayer and ThePlayer.SoundEmitter then
        ThePlayer.SoundEmitter:PlaySound("dontstarve/HUD/collect_resource")
    end
end

function Autoswitch:IconHide()
    if ThePlayer and ThePlayer.HUD and ThePlayer.HUD.controls and
        ThePlayer.HUD.controls.inv and ThePlayer.HUD.controls.inv.inv and
        ThePlayer.HUD.controls.inv.inv[self.chipSlot] then
        ThePlayer.HUD.controls.inv.inv[self.chipSlot]:SetBGImage2(
            "images/icon-autoswitch-hide.xml", "icon-autoswitch-hide.tex")
    end
    if ThePlayer and ThePlayer.SoundEmitter then
        ThePlayer.SoundEmitter:PlaySound("dontstarve/HUD/collect_resource")
    end
end

function Autoswitch:GetCachedItem(item)
    return CacheService:GetCachedItem(item)
end

function Autoswitch:GetWalkspeedMult(item)
    local cachedItem = self:GetCachedItem(item)
    return cachedItem
       and cachedItem.components.equippable
       and cachedItem.components.equippable.walkspeedmult
        or 0
end

function Autoswitch:OnUpdate(dt)
    local handItem = ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if self:IsAttacking() then
        self:TryEquipWeaponItem()
    elseif not self:IsCaneItem(handItem) and self:IsMoving() then
        self:TryEquipCaneItem()
    end
end

function Autoswitch:IsWeaponItem(item)
    return item and item:HasTag("weapon") and
               not (item.prefab == "cane" or item.prefab == "orangestaff")
end

function Autoswitch:IsCaneItem(item)
    -- 检查物品是否有加速属性
    -- return item and (item.prefab == "cane" or item.prefab == "orangestaff")
    return self:GetWalkspeedMult(item) > 1 and (item and item.prefab ~= "yellowamulet")
end

function Autoswitch:IsToolItem(item)
    return self.toolList[item.prefab] or (item and item:HasTag("dumbbell"))
end

function Autoswitch:IsMoving()
    return TheSim:GetDigitalControl(CONTROL_MOVE_LEFT) or
               TheSim:GetDigitalControl(CONTROL_MOVE_RIGHT) or
               TheSim:GetDigitalControl(CONTROL_MOVE_DOWN) or
               TheSim:GetDigitalControl(CONTROL_MOVE_UP)
end

function Autoswitch:CalcRange(weapon)
    return 3 + ((weapon and self.weaponList[weapon.prefab]) or 1)
end

function Autoswitch:IsAttacking()
    if TheSim:GetDigitalControl(CONTROL_ATTACK) or TheSim:GetDigitalControl(CONTROL_CONTROLLER_ATTACK) or TheSim:GetDigitalControl(CONTROL_MENU_MISC_1) then
        local x, y, z = ThePlayer:GetPosition():Get()
        local weapon = ThePlayer.replica.inventory:GetItemInSlot(self.chipSlot)
        return next(TheSim:FindEntities(x, y, z, self:CalcRange(weapon), nil, {
            "abigail", "player", "structure", "wall"
        }, {"_combat", "hostile"}))
    else
        return false
    end
end

function Autoswitch:TryEquipWeaponItem()
    local item = ThePlayer.replica.inventory:GetItemInSlot(self.chipSlot)
    if self:IsWeaponItem(item) then
        SendRPCToServer(RPC.EquipActionItem, item)
    end
end

function Autoswitch:TryEquipCaneItem()
    local inventoryList = ThePlayer.replica.inventory:GetItems()
    local handItem = ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    -- 如果手持工具则不切换手杖
    if handItem and self:IsToolItem(handItem) then
        return
    end
    for _, item in pairs(inventoryList) do
        if self:IsCaneItem(item) then
            SendRPCToServer(RPC.EquipActionItem, item)
            return
        end
    end
end

return Autoswitch
