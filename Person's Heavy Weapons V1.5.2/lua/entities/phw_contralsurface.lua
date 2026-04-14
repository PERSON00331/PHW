AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Control Surface"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

ENT.PanelModel  = "models/hunter/plates/plate075x3.mdl"

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.PanelModel)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self:SetMaterial("phoenix_storms/cube")

        self.PitchUp  = 0
        self.PitchDown = 0

        self.Inputs = WireLib.CreateInputs(self, { "PitchUp", "PitchDown" })
        self.Outputs = WireLib.CreateOutputs(self, { "Active" })
    end

    function ENT:TriggerInput(name, value)
        if name == "PitchUp" then
            self.PitchUp = value
        elseif name == "PitchDown" then
            self.PitchDown = value
        end

        local active = (self.PitchUp > 0 or self.PitchDown > 0)
        WireLib.TriggerOutput(self, "Active", active and 1 or 0)
    end

    function ENT:Think()
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            if self.PitchUp > 0 then
                phys:ApplyForceCenter(self:GetUp() * 5000 * self.PitchUp)
            end

            if self.PitchDown > 0 then
                phys:ApplyForceCenter(self:GetUp() * -5000 * self.PitchDown)
            end
        end

        self:NextThink(CurTime() + 0.05)
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
