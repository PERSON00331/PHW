TOOL.Category   = "P.H.W V1"
TOOL.Name       = "PHW Armorizer"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    thickness = "60"
}

if SERVER then
    util.AddNetworkString("PHW_ArmorFeedback")

    local function SendArmorFeedback(ply, msg)
        net.Start("PHW_ArmorFeedback")
        net.WriteString(msg or "")
        net.Send(ply)
    end

    local function CalcArmorStats(thickness)
        local hp = math.Clamp(25 + (thickness * 0.45), 25, 300)
        local mass = math.Clamp(25 + (thickness * 1.2), 25, 750)
        return hp, mass
    end

    local function SaveArmorForDupe(ent)
        if not IsValid(ent) or not ent.IsPHWArmor then return end
        local mod = {
            HP = ent.ArmorHP,
            MaxHP = ent.ArmorMaxHP,
            Thickness = ent.ArmorThickness
        }
        duplicator.StoreEntityModifier(ent, "PHWArmor", mod)
    end

    duplicator.RegisterEntityModifier("PHWArmor", function(ply, ent, data)
        if not IsValid(ent) then return end
        ent.IsPHWArmor = true
        ent.ArmorHP = data.HP or 25
        ent.ArmorMaxHP = data.MaxHP or 25
        ent.ArmorThickness = data.Thickness or 0

        ent.OnTakeDamage = function(self, dmginfo)
            local t = dmginfo:GetDamageType()
            local isFireOrExplosion = bit.band(t, DMG_BLAST) ~= 0
                or bit.band(t, DMG_BURN) ~= 0
                or bit.band(t, DMG_SLOWBURN) ~= 0

            if not isFireOrExplosion then
                self:EmitSound("physics/metal/metal_solid_impact_bullet1.wav", 70, 100, 0.6, CHAN_AUTO)
                return
            end

            self.ArmorHP = math.max(0, self.ArmorHP - dmginfo:GetDamage())
            self:EmitSound("physics/metal/metal_box_impact_hard1.wav", 70, 100, 0.6, CHAN_AUTO)

            if self.ArmorHP <= 0 then
                self:EmitSound("physics/metal/metal_sheet_impact_hard2.wav", 80, 95, 1, CHAN_AUTO)
                self:Remove()
            end
        end
    end)

    function TOOL:LeftClick(trace)
        local ply = self:GetOwner()
        local ent = trace.Entity
        if not IsValid(ent) or ent:IsPlayer() then return false end

        local thickness = self:GetClientNumber("thickness", 60)
        local hp, mass = CalcArmorStats(thickness)

        ent.IsPHWArmor = true
        ent.ArmorHP = hp
        ent.ArmorMaxHP = hp
        ent.ArmorThickness = thickness

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(mass)
        end

        ent.OnTakeDamage = function(self, dmginfo)
            local t = dmginfo:GetDamageType()
            local isFireOrExplosion = bit.band(t, DMG_BLAST) ~= 0
                or bit.band(t, DMG_BURN) ~= 0
                or bit.band(t, DMG_SLOWBURN) ~= 0

            if not isFireOrExplosion then
                self:EmitSound("physics/metal/metal_solid_impact_bullet1.wav", 70, 100, 0.6, CHAN_AUTO)
                return
            end

            self.ArmorHP = math.max(0, self.ArmorHP - dmginfo:GetDamage())
            self:EmitSound("physics/metal/metal_box_impact_hard1.wav", 70, 100, 0.6, CHAN_AUTO)

            if self.ArmorHP <= 0 then
                self:EmitSound("physics/metal/metal_sheet_impact_hard2.wav", 80, 95, 1, CHAN_AUTO)
                self:Remove()
            end
        end

        SaveArmorForDupe(ent)

        SendArmorFeedback(ply, "Converted "..tostring(ent).." into armor (HP "..string.format("%.2f", hp)..", Mass "..string.format("%.2f", mass)..")")
        return true
    end

    function TOOL:RightClick(trace)
        local ply = self:GetOwner()
        local ent = trace.Entity
        if not IsValid(ent) or not ent.IsPHWArmor then return false end

        local phys = ent:GetPhysicsObject()
        local mass = IsValid(phys) and phys:GetMass() or 0
        SendArmorFeedback(ply,
            "Prop: "..tostring(ent:GetModel())..
            " | HP: "..string.format("%.2f", ent.ArmorHP).."/"..string.format("%.2f", ent.ArmorMaxHP)..
            " | Thickness: "..string.format("%.2f", ent.ArmorThickness)..
            " | Mass: "..string.format("%.2f", mass)
        )
        return true
    end

    function TOOL:Reload(trace)
        local ply = self:GetOwner()
        local ent = trace.Entity
        if not IsValid(ent) or not ent.IsPHWArmor then return false end

        ent.IsPHWArmor = nil
        ent.ArmorHP = nil
        ent.ArmorMaxHP = nil
        ent.ArmorThickness = nil
        ent.OnTakeDamage = nil

        duplicator.ClearEntityModifier(ent, "PHWArmor")

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(phys:GetMass()) -- resets to whatever default physics mass was
        end

        SendArmorFeedback(ply, "Cleared armor from "..tostring(ent))
        return true
    end
end

if CLIENT then
    language.Add("tool.phw_armorizer.name", "PHW Armorizer")
    language.Add("tool.phw_armorizer.desc", "Convert props into armor with thickness scaling")
    language.Add("tool.phw_armorizer.0", "Left Click: Armorize prop | Right Click: Show stats | Reload: Clear armor")

    net.Receive("PHW_ArmorFeedback", function()
        local msg = net.ReadString()
        chat.AddText(Color(0,200,255), "[PHW Armor] ", Color(255,255,255), msg)
    end)

    function TOOL.BuildCPanel(panel)
        panel:AddControl("Slider", {
            Label = "Thickness",
            Command = "phw_armorizer_thickness",
            Type = "Float",
            Min = 0,
            Max = 600
        })

        local hpBar = vgui.Create("DProgress")
        hpBar:SetTall(20)
        panel:AddItem(hpBar)
        local hpLabel = vgui.Create("DLabel")
        hpLabel:SetTextColor(Color(255,0,0))
        panel:AddItem(hpLabel)

        local thickBar = vgui.Create("DProgress")
        thickBar:SetTall(20)
        panel:AddItem(thickBar)
        local thickLabel = vgui.Create("DLabel")
        thickLabel:SetTextColor(Color(255,0,0))
        panel:AddItem(thickLabel)

        local massBar = vgui.Create("DProgress")
        massBar:SetTall(20)
        panel:AddItem(massBar)
        local massLabel = vgui.Create("DLabel")
        massLabel:SetTextColor(Color(255,0,0))
        panel:AddItem(massLabel)

        local function UpdateBars()
            local thickness = GetConVar("phw_armorizer_thickness"):GetFloat()
            local hp = math.Clamp(25 + (thickness * 0.45), 25, 300)
            local mass = math.Clamp(25 + (thickness * 1.2), 25, 750)

            hpBar:SetFraction(hp / 300)
            thickBar:SetFraction(thickness / 600)
            massBar:SetFraction(mass / 750)

            hpLabel:SetText("HP: "..string.format("%.2f", hp))
            thickLabel:SetText("Thickness: "..string.format("%.2f", thickness))
            massLabel:SetText("Mass: "..string.format("%.2f", mass))
        end

        timer.Create("PHWArmorizerBars", 0.1, 0, UpdateBars)
    end
end
