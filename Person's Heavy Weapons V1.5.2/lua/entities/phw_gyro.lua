AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type      = "anim"
ENT.PrintName = "Horizontal Level Gyro"
ENT.Author    = "Person"
ENT.Category  = "P.H.W"
ENT.Spawnable = true

ENT.Model = "models/bull/various/gyroscope.mdl"

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local p = self:GetPhysicsObject()
        if IsValid(p) then p:Wake() end

        self.Active = 0

        self.Inputs = WireLib.CreateInputs(self, {
            "Active"
        })
    end

    function ENT:TriggerInput(n, v)
        if n == "Active" then
            self.Active = v
        end
    end

    function ENT:Think()
        if self.Active > 0 then
            local obj = self

            if IsValid(self:GetParent()) then
                obj = self:GetParent()
            end

            local ang = obj:GetAngles()
            local new = Angle(0, ang.y, 0)

            obj:SetAngles(new)
        end

        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
