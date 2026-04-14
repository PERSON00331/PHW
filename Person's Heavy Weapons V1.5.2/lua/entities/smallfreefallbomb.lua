AddCSLuaFile()

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Small Free Fall Bomb"
ENT.Author          = "Person"
ENT.Category        = "P.H.W"
ENT.Spawnable       = true
ENT.AdminOnly       = false

ENT.Model                   = "models/props_phx/ww2bomb.mdl"
ENT.ImpactSpeedThreshold    = 350
ENT.ImpactDeltaMin          = 0.12
ENT.ArmDelay                = 0.9
ENT.RadiusUnfreeze          = 215
ENT.RadiusRemove            = 99
ENT.UnfreezeConstraintType  = "Weld"
ENT.Sound_Explode           = "BaseExplosionEffect.Sound"
ENT.PhysgunCooldown         = 2

local NETMSG = "SmallBomb_Explode"
if SERVER then
    util.AddNetworkString(NETMSG)
end

local function IsRemovableProp(ent)
    if not IsValid(ent) then return false end
    local class = ent:GetClass()
    return (class == "prop_physics" or class == "prop_physics_multiplayer" or class == "func_breakable")
end

local function IsPhysicsEntity(ent)
    if not IsValid(ent) then return false end
    local phys = ent:GetPhysicsObject()
    return IsValid(phys)
end

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(3)
            phys:Wake()
        end
        self.ArmTime = CurTime() + self.ArmDelay
        self.HasDetonated = false
        self.LastPhysgunRelease = 0
    end

    function ENT:Think()
        if self:IsPlayerHolding() then
            self.LastPhysgunRelease = CurTime()
        end
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            local welded = false
            local constraints = constraint.FindConstraints(self, "Weld")
            if constraints and #constraints > 0 then
                welded = true
            end
            if welded and phys:GetMass() ~= 3 then
                phys:SetMass(3)
            elseif not welded and phys:GetMass() ~= 150 then
                phys:SetMass(455)
            end
        end
        self:NextThink(CurTime() + 0.05)
        return true
    end

    function ENT:PhysicsCollide(data, physobj)
        if self.HasDetonated then return end
        if CurTime() < (self.ArmTime or 0) then return end
        if self:IsPlayerHolding() then return end
        if CurTime() - (self.LastPhysgunRelease or 0) < self.PhysgunCooldown then return end
        local speed = data.Speed or 0
        local dt    = data.DeltaTime or 0
        if speed >= self.ImpactSpeedThreshold and dt >= self.ImpactDeltaMin then
            self:Detonate()
        end
    end

    function ENT:Detonate()
        if self.HasDetonated then return end
        self.HasDetonated = true
        local pos = self:GetPos()
        local up  = self:GetUp()
        net.Start(NETMSG)
            net.WriteVector(pos)
        net.Broadcast()
        self:EmitSound(self.Sound_Explode, 85, 110, 1, CHAN_AUTO)
        util.Decal("Scorch", pos + up * 6, pos - up * 12, self)
        for _, ent in ipairs(ents.FindInSphere(pos, self.RadiusUnfreeze)) do
            if ent ~= self and IsPhysicsEntity(ent) then
                local phys = ent:GetPhysicsObject()
                phys:EnableMotion(true)
                phys:Wake()
                constraint.RemoveConstraints(ent, self.UnfreezeConstraintType)
                if IsValid(ent:GetParent()) then
                    ent:SetParent(nil)
                end
                local dir = (ent:GetPos() - pos)
                local dist = math.max(dir:Length(), 1)
                dir:Normalize()
                local force = 9000 * (1 - math.Clamp(dist / self.RadiusUnfreeze, 0, 1))
                phys:ApplyForceCenter(dir * force)
            end
        end
        for _, ent in ipairs(ents.FindInSphere(pos, self.RadiusRemove)) do
            if ent ~= self and IsRemovableProp(ent) then
                ent:Remove()
            end
        end
        local dmginfo = DamageInfo()
        dmginfo:SetDamage(45)
        dmginfo:SetDamageType(DMG_BLAST)
        dmginfo:SetInflictor(self)
        dmginfo:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
        util.BlastDamageInfo(dmginfo, pos, self.RadiusUnfreeze)
        util.ScreenShake(pos, 10, 80, 0.6, 2000)
        SafeRemoveEntityDelayed(self, 0)
    end

end

if CLIENT then
    net.Receive(NETMSG, function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos, false)
        if not emitter then return end

        local smoketex = {
            "particle/particle_smokegrenade",
            "particle/smokesprites_0001",
            "particle/smokesprites_0002",
            "particle/smokesprites_0003",
            "particle/smokesprites_0004",
            "particle/smokesprites_0010",
            "particle/smokesprites_0012",
            "particle/smokesprites_0014"
        }

        for i = 1, 18 do
            local p = emitter:Add("sprites/orangecore2", pos)
            if p then
                p:SetVelocity(VectorRand() * 120 + Vector(0,0,160))
                p:SetDieTime(math.Rand(0.18, 0.32))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(60, 90))
                p:SetEndSize(math.Rand(120, 160))
                p:SetColor(255,140,40)
                p:SetAirResistance(30)
                p:SetGravity(Vector(0,0,-150))
            end
        end

        for i = 1, 6 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos)
            if p then
                p:SetVelocity(VectorRand() * 180 + Vector(0,0,120))
                p:SetDieTime(math.Rand(4.5, 6.5))
                p:SetStartAlpha(200)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(40, 60))
                p:SetEndSize(math.Rand(250, 350))
                p:SetColor(50,50,50)
                p:SetAirResistance(40)
                p:SetGravity(Vector(0,0,math.Rand(10,40)))
            end
        end

        for i = 1, 4 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos + Vector(0,0,4))
            if p then
                p:SetVelocity(VectorRand() * 500)
                p:SetDieTime(math.Rand(3.0, 4.0))
                p:SetStartAlpha(180)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(30, 45))
                p:SetEndSize(math.Rand(200, 300))
                p:SetColor(30,30,30)
                p:SetAirResistance(20)
                p:SetGravity(Vector(0,0,-80))
            end
        end

        for i = 1, 8 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos)
            if p then
                local dir = VectorRand()
                dir.z = 0
                p:SetVelocity(dir * math.Rand(300, 500))
                p:SetDieTime(math.Rand(2.0, 3.0))
                p:SetStartAlpha(150)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(30, 50))
                p:SetEndSize(math.Rand(200, 300))
                p:SetColor(80,70,60)
                p:SetAirResistance(15)
                p:SetGravity(Vector(0,0,0))
            end
        end

        local shock = emitter:Add("particle/warp1_warp", pos)
        if shock then
            shock:SetDieTime(0.25)
            shock:SetStartAlpha(255)
            shock:SetEndAlpha(0)
            shock:SetStartSize(20)
            shock:SetEndSize(500)
            shock:SetColor(255,255,255)
        end

        local ring = emitter:Add("particle/Particle_Ring_Blur", pos)
        if ring then
            ring:SetDieTime(0.35)
            ring:SetStartAlpha(255)
            ring:SetEndAlpha(0)
            ring:SetStartSize(1)
            ring:SetEndSize(600)
            ring:SetColor(255,255,255)
        end

        emitter:Finish()
    end)
end
