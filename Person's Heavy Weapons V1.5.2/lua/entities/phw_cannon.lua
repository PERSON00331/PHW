AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Cannon"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
   -- util.AddNetworkString("Cannon_Poof")

    function ENT:Initialize()
        self:SetModel("models/weapons/w_rocket_launcher.mdl")
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
        local radius = 150
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
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
        self.NextFire = CurTime() + 15
        local muzzlePos = self:GetPos() + self:GetForward() * 60
        self:EmitSound("Weapon_RPG.Single", 90, 100, 1, CHAN_WEAPON)
   --     net.Start("Cannon_Poof")
        net.WriteVector(muzzlePos)
        net.Broadcast()
    end

    function ENT:FireProjectile(driver)
        local proj = ents.Create("cannon_projectile")
        if not IsValid(proj) then return end
        local spawnPos = self:GetPos() + self:GetForward() * -90
        proj:SetPos(spawnPos)
        proj:SetAngles(self:GetAngles())
        proj:SetOwner(driver or self)
        proj:Spawn()
        local phys = proj:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(self:GetForward() * -950000000)
        end
    end
end
