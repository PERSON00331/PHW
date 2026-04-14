AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Disconnecter"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
    util.AddNetworkString("Disconnecter_Poof")

    function ENT:Initialize()
        self:SetModel("models/hunter/blocks/cube075x075x025.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetMaterial("phoenix_storms/cube")
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
        self.firing = false
        self.Inputs = WireLib.CreateInputs(self, { "Fire" })
    end

    function ENT:TriggerInput(name, value)
        if name == "Fire" then
            if value > 0 then
                self:DoPoof()
            end
        end
    end

    function ENT:Think()
        self:NextThink(CurTime())
        return true
    end

    function ENT:Use(activator, caller)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        self:DoPoof()
    end

    function ENT:DoPoof()
        net.Start("Disconnecter_Poof")
        net.WriteVector(self:GetPos())
        net.Broadcast()
        self:EmitSound("NPC_Sniper.SonicBoom", 75, 100)
        self:Remove()
    end
end

if CLIENT then
    net.Receive("Disconnecter_Poof", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end
        for i = 1, 30 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * 350 + Vector(0,0,80))
                p:SetDieTime(math.Rand(0.6, 3.2))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(10, 20))
                p:SetEndSize(math.Rand(60, 90))
                p:SetRoll(math.Rand(0, 360))
                p:SetRollDelta(math.Rand(-2, 2))
                p:SetColor(200, 200, 200)
                p:SetAirResistance(501)
                p:SetGravity(Vector(0, 0, -200))
            end
        end
        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end
