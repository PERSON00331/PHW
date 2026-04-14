AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Scatter Cannon"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
    util.AddNetworkString("ScatterCannon_FireFX")

    function ENT:Initialize()
        self:SetModel("models/weapons/w_shotgun.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
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
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 140)) do
            if IsValid(ent) and ent:GetClass() == "cannon_ammo" then
                ammoNearby = true
                break
            end
        end
        if not ammoNearby then
            self:EmitSound("buttons/button10.wav", 75, 100, 1, CHAN_AUTO)
            return
        end
        self:FireScatter(driver)
        self.NextFire = CurTime() + 4
        local muzzlePos = self:GetPos() + self:GetForward() * 50
        self:EmitSound("Weapon_Shotgun.Single", 90, 100, 1, CHAN_WEAPON)
        net.Start("ScatterCannon_FireFX")
        net.WriteVector(muzzlePos)
        net.Broadcast()
    end

    function ENT:FireScatter(driver)
        local origin = self:GetPos() + self:GetForward() * -60
        local baseAng = self:GetAngles()
        for i = 1, 6 do
            local offset = Angle(math.Rand(-6,6), math.Rand(-6,6), 0)
            local spawnAng = baseAng + offset
            local proj = ents.Create("autocannon_projectile")
            if not IsValid(proj) then continue end
            proj:SetPos(origin)
            proj:SetAngles(spawnAng)
            proj:SetOwner(driver or self)
            proj:Spawn()
            local phys = proj:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(spawnAng:Forward() * -45000)
            end
        end
    end
end

if CLIENT then
    net.Receive("ScatterCannon_FireFX", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end
        for i = 1, 25 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * 200 + Vector(0,0,60))
                p:SetDieTime(math.Rand(0.4, 1.2))
                p:SetStartAlpha(200)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(8, 14))
                p:SetEndSize(math.Rand(30, 50))
                p:SetColor(180, 180, 180)
            end
        end
        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end
