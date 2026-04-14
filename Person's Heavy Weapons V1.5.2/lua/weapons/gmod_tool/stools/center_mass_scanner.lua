TOOL.Category   = "P.H.W V1"
TOOL.Name       = "Center of Mass Scanner"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.Information = {
    { name = "left" },
    { name = "reload" }
}

TOOL.Description = "Tracks COM (Center of Mass) for selected contraption"

if SERVER then
    util.AddNetworkString("PHW_CenterMassFeedback")

    local function SendCenterMass(ply, msg)
        net.Start("PHW_CenterMassFeedback")
            net.WriteString(msg or "")
        net.Send(ply)
    end

    function TOOL:LeftClick(trace)
        local ply = self:GetOwner()
        local ent = trace.Entity
        if not IsValid(ent) or not ent:GetPhysicsObject():IsValid() then return false end

        local group = constraint.GetAllConstrainedEntities(ent)
        if not group or table.Count(group) == 0 then return false end

        if IsValid(ply.CenterMassMarker) then ply.CenterMassMarker:Remove() end

        local marker = ents.Create("prop_dynamic")
        if IsValid(marker) then
            marker:SetModel("models/mechanics/solid_steel/sheetmetal_plusb_4.mdl")
            marker:SetMaterial("models/shiny")
            marker:SetColor(Color(0,255,0,200))
            marker:Spawn()
            marker:SetMoveType(MOVETYPE_NONE)
            marker:SetSolid(SOLID_NONE)
            ply.CenterMassMarker = marker
            ply.CenterMassGroup = group
        end

        SendCenterMass(ply, "Center of mass marker active.")
        return true
    end

    function TOOL:Reload(trace)
        local ply = self:GetOwner()
        if IsValid(ply.CenterMassMarker) then
            ply.CenterMassMarker:Remove()
            ply.CenterMassMarker = nil
        end
        ply.CenterMassGroup = nil
        SendCenterMass(ply, "Center of mass marker cleared.")
        return true
    end

    -- l
    hook.Add("Think", "PHW_UpdateCenterMassMarkers", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply.CenterMassMarker) and ply.CenterMassGroup then
                local totalMass, weightedPos = 0, Vector(0,0,0)
                for _, e in pairs(ply.CenterMassGroup) do
                    if IsValid(e) then
                        local phys = e:GetPhysicsObject()
                        if IsValid(phys) then
                            local mass = phys:GetMass()
                            totalMass = totalMass + mass
                            weightedPos = weightedPos + e:GetPos() * mass
                        end
                    end
                end
                if totalMass > 0 then
                    local center = weightedPos / totalMass
                    ply.CenterMassMarker:SetPos(center)
                end
            end
        end
    end)
end

if CLIENT then
    local lastMsg = ""

    net.Receive("PHW_CenterMassFeedback", function()
        lastMsg = net.ReadString()
    end)

    hook.Add("HUDPaint", "PHW_CenterMassHUD", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or not wep:GetClass():StartWith("gmod_tool") then return end
        local tool = ply:GetTool()
        if not tool or tool.Mode ~= "center_mass_scanner" then return end

        -- M panel
        if lastMsg ~= "" then
            local w, h = 360, 120
            local x, y = ScrW()/2 - w/2, ScrH() - h - 50
            draw.RoundedBox(8, x, y, w, h, Color(0,0,0,180))
            draw.SimpleText("Center of Mass Scanner", "Trebuchet24", x + w/2, y + 10, Color(255,255,255), TEXT_ALIGN_CENTER)
            draw.SimpleText(lastMsg, "Trebuchet18", x + 10, y + 50, Color(0,255,0), TEXT_ALIGN_LEFT)
        end

        local cw, ch = 240, 100
        local cx, cy = ScrW() - cw - 20, 20
        draw.RoundedBox(8, cx, cy, cw, ch, Color(0,0,0,180))
        draw.SimpleText("Controls:", "Trebuchet18", cx + 10, cy + 10, Color(255,255,255), TEXT_ALIGN_LEFT)
        draw.SimpleText("Left Click: Track COM of selected contraption", "Trebuchet18", cx + 10, cy + 30, Color(200,200,200), TEXT_ALIGN_LEFT)
        draw.SimpleText("Reload (R): Clear Marker", "Trebuchet18", cx + 10, cy + 50, Color(200,200,200), TEXT_ALIGN_LEFT)
    end)
end
