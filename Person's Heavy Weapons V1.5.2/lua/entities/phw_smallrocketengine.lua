AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")


ENT.Type      = "anim"
ENT.PrintName = "Small Rocket Engine"
ENT.Author    = "Person"
ENT.Category  = "P.H.W"
ENT.Spawnable = true

ENT.Model = "models/xqm/afterburner1big.mdl"

local NETMSG_FX = "PHW_SmallRocketEngine_FX"

if SERVER then
    util.AddNetworkString(NETMSG_FX)
end

local function HasFuelNearby(ent)
    for _, e in ipairs(ents.FindInSphere(ent:GetPos(), 250)) do
        if e:GetClass() == "phw_fuel" then
            return true
        end
    end
    return false
end

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(255)
            phys:Wake()
        end

        self.ActiveIn = 0
        self.NextFX = 0
        self.EngineSound = nil

        self.Inputs = WireLib.CreateInputs(self, {
            "Active"
        })
    end

    function ENT:TriggerInput(name, val)
        if name == "Active" then self.ActiveIn = val end
    end

    function ENT:StartEngineSound()
        if self.EngineSound then return end
        self.EngineSound = CreateSound(self, "Phx.Afterburner5")
        if self.EngineSound then
            self.EngineSound:PlayEx(1, 100)
        end
    end

    function ENT:StopEngineSound()
        if self.EngineSound then
            self.EngineSound:FadeOut(0.2)
            self.EngineSound = nil
        end
    end

    function ENT:Think()
        local phys = self:GetPhysicsObject()
        if not IsValid(phys) then return end

        local fueled = HasFuelNearby(self)
        local active = self.ActiveIn > 0 and fueled

        if active then
            self:StartEngineSound()
            phys:ApplyForceCenter(self:GetUp() * -9000)

            if CurTime() > self.NextFX then
                net.Start(NETMSG_FX)
                net.WriteVector(self:GetPos() + self:GetUp() * 20)
                net.Broadcast()
                self.NextFX = CurTime() + 0.04
            end
        else
            self:StopEngineSound()
        end

        self:NextThink(CurTime() + 0.02)
        return true
    end

    function ENT:OnRemove()
        self:StopEngineSound()
    end
end

if CLIENT then

    net.Receive(NETMSG_FX, function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos, false)
        if not emitter then return end

        local p = emitter:Add("sprites/orangecore2", pos)
        if p then
            p:SetVelocity(Vector(0,0,-300) + VectorRand() * 40)
            p:SetDieTime(0.25)
            p:SetStartAlpha(255)
            p:SetEndAlpha(0)
            p:SetStartSize(20)
            p:SetEndSize(60)
            p:SetColor(255,160,60)
        end

        local s = emitter:Add("particle/particle_smokegrenade", pos)
        if s then
            s:SetVelocity(Vector(0,0,-200) + VectorRand() * 55)
            s:SetDieTime(1.5)
            s:SetStartAlpha(255)
            s:SetEndAlpha(0)
            s:SetStartSize(18)
            s:SetEndSize(120)
            s:SetColor(255,255,255)
        end

        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end
