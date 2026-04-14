AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Mortar Cannon"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
    util.AddNetworkString("MortarCannon_FireFX")

    function ENT:Initialize()
        self:SetModel("models/props_c17/oildrum001.mdl")
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
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 150)) do
            if IsValid(ent) and ent:GetClass() == "cannon_ammo" then
                ammoNearby = true
                break
            end
        end
        if not ammoNearby then
            self:EmitSound("buttons/button10.wav", 75, 100, 1, CHAN_AUTO)
            return
        end
        self:FireShell(driver)
        self.NextFire = CurTime() + 8
        local muzzlePos = self:GetPos() + self:GetUp() * 40
        self:EmitSound("Weapon_Mortar.Single", 90, 100, 1, CHAN_WEAPON)
        net.Start("MortarCannon_FireFX")
        net.WriteVector(muzzlePos)
        net.Broadcast()
    end

    function ENT:FireShell(driver)
        local proj = ents.Create("cannon_projectile")
        if not IsValid(proj) then return end
        local spawnPos = self:GetPos() + self:GetUp() * 50
        proj:SetPos(spawnPos)
        proj:SetAngles(self:GetAngles())
        proj:SetOwner(driver or self)
        proj:Spawn()
        local phys = proj:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(self:GetUp() * 9999)
        end
    end
end

if CLIENT then
    net.Receive("MortarCannon_FireFX", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end
        for i = 1, 20 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * 150 + Vector(0,0,120))
                p:SetDieTime(math.Rand(0.6, 1.2))
                p:SetStartAlpha(200)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(10, 18))
                p:SetEndSize(math.Rand(35, 55))
                p:SetColor(180, 180, 180)
            end
        end
        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end
