AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_gmodentity"
ENT.PrintName   = "PHW Motor Battery"
ENT.Author      = "Person"
ENT.Spawnable   = false
ENT.Category    = "P.H.W"

if SERVER then -- w ip
    function ENT:Initialize()
        self:SetModel("models/items/car_battery01.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(50)
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
