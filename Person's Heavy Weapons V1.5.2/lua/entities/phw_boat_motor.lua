AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Boat Propeller"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

local function IsPosInWater(pos)
    return bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/gibs/airboat_broken_engine.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
        self.ThrustForce   = 0
        self.MaxThrust     = 9999
        self.ThrustGain    = 5555
        self.ThrustLoss    = 4444
        self.Active        = false
        self.LastInputTime = 0
        self.PropLoop      = nil
        self.firing        = false
        self.Inputs = WireLib.CreateInputs(self, { "Fire" })
        self.Outputs = WireLib.CreateOutputs(self, { "Active" })
    end

    function ENT:TriggerInput(name, value)
        if name == "Fire" then
            if value > 0 then
                if self:HasFuelNearby() then
                    self.Active = true
                    self.LastInputTime = CurTime()
                end
            end
        end
    end

    function ENT:HasFuelNearby()
        local radius = 250
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
            if IsValid(ent) and ent:GetClass() == "phw_fuel" then
                return true
            end
        end
        return false
    end

    function ENT:IsInWater()
        if self:WaterLevel() and self:WaterLevel() > 1 then return true end
        return IsPosInWater(self:WorldSpaceCenter()) or IsPosInWater(self:GetPos())
    end

    function ENT:UpdatePropSound()
        local wantLoop = self.ThrustForce > 0 and self:IsInWater()
        if wantLoop then
            if not self.PropLoop then
                self.PropLoop = CreateSound(self, "vehicles/airboat/fan_blade_fullthrottle_loop1.wav")
            end
            if self.PropLoop then
                local frac  = math.Clamp(self.ThrustForce / self.MaxThrust, 0, 1)
                local vol   = Lerp(frac, 0.35, 0.95)
                local pitch = math.floor(Lerp(frac, 90, 120))
                self.PropLoop:PlayEx(vol, pitch)
            end
        else
            if self.PropLoop then
                self.PropLoop:FadeOut(0.3)
            end
        end
    end

    function ENT:OnRemove()
        if self.PropLoop then
            self.PropLoop:Stop()
            self.PropLoop = nil
        end
    end

    function ENT:Think()
        if CurTime() - self.LastInputTime > 0.2 then
            self.Active = false
        end
        if not self:HasFuelNearby() then
            self.Active = false
        end
        if self.Active then
            self.ThrustForce = math.min(self.ThrustForce + self.ThrustGain, self.MaxThrust)
        else
            self.ThrustForce = math.max(self.ThrustForce - self.ThrustLoss, 0)
        end
        WireLib.TriggerOutput(self, "Active", self.Active and 1 or 0)
        local canThrust = self.ThrustForce > 0 and self:IsInWater()
        if canThrust then
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(self:GetForward() * self.ThrustForce)
            end
        end
        self:UpdatePropSound()
        self:NextThink(CurTime() + 0.05)
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
