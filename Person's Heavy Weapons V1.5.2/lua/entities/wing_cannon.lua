AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Wing Cannon"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
    util.AddNetworkString("WingCannon_Poof")

    function ENT:Initialize()
        self:SetModel("models/weapons/w_stunbaton.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(55)
        end
        self.NextFire = 0
        self.firing = false
        self.Inputs = WireLib.CreateInputs(self, { "Fire" })
    end

    function ENT:TriggerInput(name, value)
        if name == "Fire" then
            self.firing = value > 0
        end
    end

    function ENT:Think()
        if self.firing then
            self:TryFire(self)
        end
        self:NextThink(CurTime())
        return true
    end

    function ENT:Use(activator, caller)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        self:TryFire(activator)
    end

    function ENT:TryFire(driver)
        if CurTime() < self.NextFire then return end
        local ammoNearby = false
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 145)) do
            if IsValid(ent) and ent:GetClass() == "cannon_ammo" then
                ammoNearby = true
                break
            end
        end
        if not ammoNearby then
            self:EmitSound("buttons/button10.wav", 75, 100, 1, CHAN_AUTO)
            return
        end
        self:FireProjectile(driver)
        self.NextFire = CurTime() + 0.3
        local muzzlePos = self:GetPos() + self:GetForward() * 60
        self:EmitSound("weapons/explode3.wav", 90, 100, 1, CHAN_WEAPON)
        net.Start("WingCannon_Poof")
        net.WriteVector(muzzlePos)
        net.Broadcast()
    end

    function ENT:FireProjectile(driver)
        local proj = ents.Create("autocannon_projectile")
        if not IsValid(proj) then return end
        local spawnPos = self:GetPos() + self:GetForward() * -90
        proj:SetPos(spawnPos)
        proj:SetAngles(self:GetAngles())
        proj:SetOwner(driver or self)
        proj:Spawn()
        local phys = proj:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(self:GetForward() * -9999990)
        end
    end
end

if CLIENT then
    net.Receive("WingCannon_Poof", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end
        for i = 1, 5 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * 350 + Vector(0,0,80))
                p:SetDieTime(math.Rand(0.6, 3.2))
                p:SetStartAlpha(222)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(5, 11))
                p:SetEndSize(math.Rand(11, 21))
                p:SetRoll(math.Rand(0, 360))
                p:SetRollDelta(math.Rand(-2, 2))
                p:SetColor(200, 200, 200)
                p:SetAirResistance(33)
                p:SetGravity(Vector(0, 0, -200))
            end
        end
        emitter:Finish()
    end)
end
