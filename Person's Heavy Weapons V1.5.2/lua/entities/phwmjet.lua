AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Medium Jet Engine"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
    util.AddNetworkString("PHW_MJetFX")

    function ENT:Initialize()
        self:SetModel("models/xqm/jetenginemedium.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self.ThrustForce   = 0
        self.MaxThrust     = 656100
        self.ThrustGain    = 4444
        self.ThrustLoss    = 3598

        self.Active        = false
        self.firing        = false
        self.NextFX        = 0
        self.JetLoop       = nil
        self.NextBurn      = 0

        self.Inputs = WireLib.CreateInputs(self, { "Fire" })
        self.Outputs = WireLib.CreateOutputs(self, { "Active" })
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

    function ENT:UpdateJetSound()
        if self.ThrustForce > 0 then
            if not self.JetLoop then
                self.JetLoop = CreateSound(self, "ambient/machines/turbine_loop_1.wav")
            end
            if self.JetLoop then
                local frac = math.Clamp(self.ThrustForce / self.MaxThrust, 0, 1)
                local vol  = Lerp(frac, 0.4, 1.0)
                local pitch = math.floor(Lerp(frac, 90, 120))
                self.JetLoop:PlayEx(vol, pitch)
            end
        else
            if self.JetLoop then
                self.JetLoop:FadeOut(0.3)
            end
        end
    end

    function ENT:OnRemove()
        if self.JetLoop then
            self.JetLoop:Stop()
            self.JetLoop = nil
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
        else
            self.ThrustForce = math.max(self.ThrustForce - self.ThrustLoss, 0)
        end

        WireLib.TriggerOutput(self, "Active", self.Active and 1 or 0)

        if self.ThrustForce > 0 then
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(self:GetForward() * self.ThrustForce)
            end
        end

        self:UpdateJetSound()

        if self.ThrustForce > 0 and CurTime() > self.NextFX then
            local fxPos = self:GetPos() + self:GetForward() * -60
            local frac = math.Clamp(self.ThrustForce / self.MaxThrust, 0, 1)
            net.Start("PHW_MJetFX")
            net.WriteVector(fxPos)
            net.WriteVector(self:GetForward() * -1)
            net.WriteFloat(frac)
            net.Broadcast()
            self.NextFX = CurTime() + Lerp(frac, 0.12, 0.05)
        end

        if self.ThrustForce > 0 and CurTime() > self.NextBurn then
            self.NextBurn = CurTime() + 1
            local behindDir = -self:GetForward()
            local origin = self:GetPos()
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() then
                    local dir = (ply:GetPos() - origin):GetNormalized()
                    if dir:Dot(behindDir) > 0.7 and ply:GetPos():Distance(origin) < 200 then
                        local dmg = DamageInfo()
                        dmg:SetDamage(12)
                        dmg:SetDamageType(DMG_BURN)
                        dmg:SetAttacker(self)
                        dmg:SetInflictor(self)
                        ply:TakeDamageInfo(dmg)
                        ply:Ignite(1)
                    end
                end
            end
        end

        self:NextThink(CurTime() + 0.05)
        return true
    end
end

if CLIENT then
    net.Receive("PHW_MJetFX", function()
        local pos = net.ReadVector()
        local dir = net.ReadVector()
        local frac = net.ReadFloat()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        if frac < 0.5 then
            for i = 1, 15 do
                local p = emitter:Add("particle/particle_smokegrenade", pos)
                if p then
                    p:SetVelocity(dir * math.Rand(200, 400))
                    p:SetDieTime(math.Rand(0.8, 1.5))
                    p:SetStartAlpha(220)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(15, 25))
                    p:SetEndSize(math.Rand(50, 70))
                    p:SetColor(150, 150, 150)
                end
            end
        elseif frac < 0.9 then
            for i = 1, 10 do
                local p = emitter:Add("effects/fire_cloud1", pos)
                if p then
                    p:SetVelocity(dir * math.Rand(300, 500))
                    p:SetDieTime(math.Rand(0.2, 0.5))
                    p:SetStartAlpha(255)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(20, 30))
                    p:SetEndSize(math.Rand(40, 60))
                    p:SetColor(255, math.Rand(120,160), 0)
                end
            end
            for i = 1, 8 do
                local p = emitter:Add("particle/particle_smokegrenade", pos)
                if p then
                    p:SetVelocity(dir * math.Rand(250, 400))
                    p:SetDieTime(math.Rand(0.6, 1.2))
                    p:SetStartAlpha(180)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(12, 20))
                    p:SetEndSize(math.Rand(40, 60))
                    p:SetColor(180, 180, 180)
                end
            end
        else
            for i = 1, 12 do
                local p = emitter:Add("particle/particle_smokegrenade", pos)
                if p then
                    p:SetVelocity(dir * math.Rand(150, 300))
                    p:SetDieTime(math.Rand(1.0, 2.0))
                    p:SetStartAlpha(80)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(8, 15))
                    p:SetEndSize(math.Rand(30, 50))
                    p:SetColor(200, 200, 200)
                end
            end
        end

        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end
