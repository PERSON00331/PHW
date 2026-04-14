AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Propeller Engine"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

ENT.DefaultMaxThrust   = 259999
ENT.DefaultThrustGain  = 11999
ENT.DefaultThrustLoss  = 91900

if SERVER then
    util.AddNetworkString("PHW_PropFX")

    function ENT:Initialize()
        self:SetModel("models/vehicle/vehicle_engine_block.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self.ThrustForce   = 0
        self.MaxThrust     = self.DefaultMaxThrust
        self.ThrustGain    = self.DefaultThrustGain
        self.ThrustLoss    = self.DefaultThrustLoss

        self.Active        = false
        self.firing        = false
        self.NextFX        = 0
        self.LoopSound     = nil

        self.PropSpin       = 0
        self.PropSpinTarget = 0

        self.BasePropAngle = self:GetPhysicsObject():GetAngles()

        self.Inputs = WireLib.CreateInputs(self, { "Fire" })
        self.Outputs = WireLib.CreateOutputs(self, { "Active" })

        self:CreatePropHolo()
    end

    function ENT:CreatePropHolo()
        if IsValid(self.PropHolo) then
            self.PropHolo:Remove()
        end

        local holo = ents.Create("prop_dynamic")
        if not IsValid(holo) then return end

        holo:SetModel("models/props_phx/misc/propeller2x_small.mdl")
        holo:SetPos(self:GetPos() + self:GetForward() * 15)
--	holo:SetColor(Color(15,15,15))
holo:SetModelScale(1.2, 0)

        holo:SetAngles(self.BasePropAngle+Angle(90,0,0))
        holo:SetParent(self)
        holo:Spawn()

        self.PropHolo = holo
    end

    function ENT:TriggerInput(name, value)
        if name == "Fire" then
            self.firing = value > 0
            self.Active = self.firing
        end
    end

    function ENT:HasFuelNearby()
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 250)) do
            if IsValid(ent) and ent:GetClass() == "phw_fuel" then
                return true
            end
        end
        return false
    end

    function ENT:UpdateLoopSound()
        if self.Active and self.ThrustForce > 0 then
            if not self.LoopSound then
                self.LoopSound = CreateSound(self, "vehicles/airboat/fan_blade_fullthrottle_loop1.wav")
            end
            if self.LoopSound then
                local frac = math.Clamp(self.ThrustForce / self.MaxThrust, 0, 1)
                local vol  = Lerp(frac, 0.3, 1.0)
                local pitch = Lerp(frac, 0.1, 120)
                self.LoopSound:PlayEx(vol, pitch)
            end
        else
            if self.LoopSound then
                self.LoopSound:Stop()
                self.LoopSound = nil
            end
        end
    end

    function ENT:OnRemove()
        if self.LoopSound then
            self.LoopSound:Stop()
            self.LoopSound = nil
        end
        if IsValid(self.PropHolo) then
            self.PropHolo:Remove()
        end
    end

    function ENT:Think()
        if not self.firing then
            self.Active = false
        end
        if not self:HasFuelNearby() then
            self.Active = false
        end

        if self.Active then
            self.ThrustForce = math.min(self.ThrustForce + self.ThrustGain, self.MaxThrust)
            self.PropSpinTarget = 900
        else
            self.ThrustForce = math.max(self.ThrustForce - self.ThrustLoss, 0)
            self.PropSpinTarget = 0
        end

        WireLib.TriggerOutput(self, "Active", self.Active and 1 or 0)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) and self.ThrustForce > 0 then
            phys:ApplyForceCenter(self:GetForward() * self.ThrustForce)
        end

        self.PropSpin = Lerp(0.1, self.PropSpin, self.PropSpinTarget)

        if IsValid(self.PropHolo) then
            local ang = self.PropHolo:GetLocalAngles()
            ang:RotateAroundAxis(Vector(1,0,0),-self.PropSpin)
            self.PropHolo:SetLocalAngles(ang)
        end

        self:UpdateLoopSound()

        if self.ThrustForce > 0 and CurTime() > self.NextFX then
            local fxPos = self:GetPos() + self:GetForward() * -20
            local frac = math.Clamp(self.ThrustForce / self.MaxThrust, 0, 1)
            net.Start("PHW_PropFX")
            net.WriteVector(fxPos)
            net.WriteVector(self:GetForward() * 1)
            net.WriteFloat(frac)
            net.Broadcast()
            self.NextFX = CurTime() + Lerp(frac, 0.14, 0.06)
        end

        self:NextThink(CurTime() + 0.05)
        return true
    end
end

if CLIENT then
    net.Receive("PHW_PropFX", function()
        local pos  = net.ReadVector()
        local dir  = net.ReadVector()
        local frac = net.ReadFloat()
        local emitter = ParticleEmitter(pos, false)
        if not emitter then return end

        for i = 1, math.Round(Lerp(frac, 8, 18)) do
            local p = emitter:Add("particle/particle_smokegrenade", pos + VectorRand() * 12)
            if p then
                local spread = dir + VectorRand() * 0.25
                spread:Normalize()
                p:SetVelocity(spread * math.Rand(-160, -320))
                p:SetDieTime(math.Rand(0.6, 1.4))
                p:SetStartAlpha(math.Round(Lerp(frac, 11, 21)))
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(10, 16))
                p:SetEndSize(math.Rand(28, 46))
                p:SetColor(190, 190, 190)
                p:SetAirResistance(30)
                p:SetGravity(Vector(0, 0, -80))
            end
        end

        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end