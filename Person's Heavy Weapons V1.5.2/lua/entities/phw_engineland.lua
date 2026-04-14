AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type      = "anim"
ENT.Base      = "base_wire_entity"
ENT.PrintName = "Engine"
ENT.Author    = "Person"
ENT.Spawnable = true
ENT.Category  = "P.H.W"

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/vehicle/vehicle_engine_block.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self.ActiveIn   = 0
        self.ForwardIn  = 0
        self.BackwardIn = 0
        self.MultIn     = 10
        self.Wheels     = {}

        self.EngineSound = nil

        self.Inputs  = WireLib.CreateInputs(self, {
            "Active",
            "Forward",
            "Backward",
            "Mult",
            "Wheels [ARRAY]"
        })

        self.Outputs = WireLib.CreateOutputs(self, {
            "Active",
            "OutForward",
            "OutBackward"
        })
    end

    function ENT:TriggerInput(name, value)
        if name == "Active" then
            self.ActiveIn = value
        elseif name == "Forward" then
            self.ForwardIn = value
        elseif name == "Backward" then
            self.BackwardIn = value
        elseif name == "Mult" then
            self.MultIn = value
        elseif name == "Wheels" then
            self.Wheels = value or {}
        end
    end

    function ENT:HasFuelNearby()
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 250)) do
            if IsValid(ent) and ent:GetClass() == "phw_normfuel" then
                return true
            end
        end
        return false
    end

    function ENT:UpdateSound()
        if self.ActiveIn > 0 and self:HasFuelNearby() then
            if not self.EngineSound then
                self.EngineSound = CreateSound(self, "ambient/machines/turbine_loop_1.wav")
            end

            local pitch = 80
            if self.ForwardIn > 0 then pitch = pitch + 25 end
            if self.BackwardIn > 0 then pitch = pitch + 15 end

            self.EngineSound:PlayEx(1, pitch)
        else
            if self.EngineSound then
                self.EngineSound:FadeOut(0.3)
                self.EngineSound = nil
            end
        end
    end

    function ENT:DriveWheels()
        if self.ActiveIn <= 0 then return end
        if not self:HasFuelNearby() then return end

        local mult = 0
        if self.ForwardIn > 0 then mult = 1 end
        if self.BackwardIn > 0 then mult = -1 end
        if mult == 0 then return end

        local dir = self:GetRight() * -mult

        for _, w in ipairs(self.Wheels) do
            if IsValid(w) then
                local phys = w:GetPhysicsObject()
                if IsValid(phys) then
                    local m = phys:GetMass()
                    local torque = dir * (self.MultIn * m)
                    phys:ApplyTorqueCenter(torque)
                end
            end
        end
    end

    function ENT:Think()
        local active = (self.ActiveIn > 0 and self:HasFuelNearby())

        WireLib.TriggerOutput(self, "Active", active and 1 or 0)
        WireLib.TriggerOutput(self, "OutForward",  (active and self.ForwardIn  > 0) and 1 or 0)
        WireLib.TriggerOutput(self, "OutBackward", (active and self.BackwardIn > 0) and 1 or 0)

        self:UpdateSound()
        self:DriveWheels()

        self:NextThink(CurTime() + 0.05)
        return true
    end

    function ENT:OnRemove()
        if self.EngineSound then
            self.EngineSound:Stop()
            self.EngineSound = nil
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
