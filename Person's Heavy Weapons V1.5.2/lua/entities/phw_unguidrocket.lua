AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Unguided Rocket FFB"
ENT.Author    = "Person"
ENT.Category  = "P.H.W"
ENT.Spawnable = true

ENT.Model = "models/props_c17/canister02a.mdl"

local NETMSG    = "PHW_RocketExplode"
local NETMSG_FX = "PHW_RocketExplode_FX"

if SERVER then
    util.AddNetworkString(NETMSG)
    util.AddNetworkString(NETMSG_FX)
end

local function IsPhysicsEntity(ent)
    if not IsValid(ent) then return false end
    local phys = ent:GetPhysicsObject()
    return IsValid(phys)
end

local function IsRemovableProp(ent)
    if not IsValid(ent) then return false end
    local c = ent:GetClass()
    return c == "prop_physics" or c == "prop_physics_multiplayer" or c == "func_breakable"
end

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(115)
            phys:Wake()
        end

        self.Armed     = false
        self.Ignited   = false
        self.Detonated = false
        self.NextFX    = 0

        self.Inputs = WireLib.CreateInputs(self, { "Armed" })
    end

    function ENT:TriggerInput(name, value)
        if name == "Armed" and value > 0 then
            self.Armed = true
        end
    end

    function ENT:PhysicsCollide(data, phys)
        if not self.Armed then return end
        self:Detonate()
    end

    function ENT:Detonate()
        if self.Detonated then return end
        self.Detonated = true

        local pos = self:GetPos()
        local up  = self:GetUp()

        net.Start(NETMSG)
        net.WriteVector(pos)
        net.Broadcast()

        self:EmitSound("BaseExplosionEffect.Sound", 100, 100, 1, CHAN_AUTO)
        util.Decal("Scorch", pos + up * 8, pos - up * 16, self)

        for _, ent in ipairs(ents.FindInSphere(pos, 480)) do
            if ent ~= self and IsPhysicsEntity(ent) then
                local phys = ent:GetPhysicsObject()
                phys:EnableMotion(true)
                phys:Wake()
                constraint.RemoveConstraints(ent, "Weld")
                if IsValid(ent:GetParent()) then
                    ent:SetParent(nil)
                end
                local dir = ent:GetPos() - pos
                local dist = math.max(dir:Length(), 1)
                dir:Normalize()
                local force = 30000 * (1 - math.Clamp(dist / 480, 0, 1))
                phys:ApplyForceCenter(dir * force)
            end
        end

        for _, ent in ipairs(ents.FindInSphere(pos, 215)) do
            if ent ~= self and IsRemovableProp(ent) then
                ent:Remove()
            end
        end

        for _, ent in ipairs(ents.FindInSphere(pos, 150)) do
            if ent ~= self then
                local c = ent:GetClass()
                if c == "prop_physics" or c == "prop_physics_multiplayer" then
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(true)
                        phys:Wake()
                    end
                end
            end
        end

        local dmginfo = DamageInfo()
        dmginfo:SetDamage(125)
        dmginfo:SetDamageType(DMG_BLAST)
        dmginfo:SetInflictor(self)
        dmginfo:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
        util.BlastDamageInfo(dmginfo, pos, 480)

        util.ScreenShake(pos, 25, 150, 1.5, 4444)

        SafeRemoveEntityDelayed(self, 0)
    end

    function ENT:Think()
        if self.Armed then
            if not self.Ignited then
                self.Ignited = true
                self:EmitSound("ambient/fire/ignite.wav", 80, 100)
            end

            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(self:GetUp() * 9000)
            end

            if CurTime() > self.NextFX then
                net.Start(NETMSG_FX)
                net.WriteVector(self:GetPos() - self:GetUp() * 20)
                net.WriteVector(-self:GetUp())
                net.Broadcast()
                self.NextFX = CurTime() + 0.05
            end
        end

        self:NextThink(CurTime() + 0.02)
        return true
    end
end

if CLIENT then

    net.Receive(NETMSG_FX, function()
        local pos = net.ReadVector()
        local dir = net.ReadVector()

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

        for i = 1, 4 do
            local p = emitter:Add("sprites/orangecore2", pos)
            if p then
                p:SetVelocity(dir * math.Rand(200, 300))
                p:SetDieTime(math.Rand(0.25, 0.45))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(40, 60))
                p:SetEndSize(math.Rand(80, 120))
                p:SetColor(255,160,60)
                p:SetAirResistance(40)
                p:SetGravity(Vector(0,0,-200))
            end
        end

        for i = 1, 3 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos)
            if p then
                p:SetVelocity(dir * math.Rand(260, 360))
                p:SetDieTime(math.Rand(2.5, 4.0))
                p:SetStartAlpha(215)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(30, 50))
                p:SetEndSize(math.Rand(140, 220))
                p:SetColor(40,40,40)
                p:SetAirResistance(55)
                p:SetGravity(Vector(0,0,math.Rand(20,60)))
            end
        end

        emitter:Finish()
    end)

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

        for i = 1, 45 do
            local p = emitter:Add("sprites/orangecore2", pos)
            if p then
                p:SetVelocity(VectorRand() * 180 + Vector(0,0,220))
                p:SetDieTime(math.Rand(0.25, 0.45))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(120, 180))
                p:SetEndSize(math.Rand(260, 340))
                p:SetColor(255,140,40)
                p:SetAirResistance(40)
                p:SetGravity(Vector(0,0,-200))
            end
        end

        for i = 1, 7 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos)
            if p then
                p:SetVelocity(VectorRand() * 260 + Vector(0,0,180))
                p:SetDieTime(math.Rand(6.5, 9.5))
                p:SetStartAlpha(215)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(90, 130))
                p:SetEndSize(math.Rand(650, 900))
                p:SetColor(40,40,40)
                p:SetAirResistance(55)
                p:SetGravity(Vector(0,0,math.Rand(20,60)))
            end
        end

        for i = 1, 5 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos + Vector(0,0,5))
            if p then
                p:SetVelocity(VectorRand() * 900)
                p:SetDieTime(math.Rand(4.5, 6.5))
                p:SetStartAlpha(200)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(60, 90))
                p:SetEndSize(math.Rand(500, 700))
                p:SetColor(25,25,25)
                p:SetAirResistance(31)
                p:SetGravity(Vector(0,0,-120))
            end
        end

        for i = 1, 15 do
            local p = emitter:Add(smoketex[math.random(#smoketex)], pos)
            if p then
                local d = VectorRand()
                d.z = 0
                p:SetVelocity(d * math.Rand(600, 900))
                p:SetDieTime(math.Rand(3.5, 5.0))
                p:SetStartAlpha(180)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(80, 120))
                p:SetEndSize(math.Rand(500, 700))
                p:SetColor(90,80,70)
                p:SetAirResistance(20)
                p:SetGravity(Vector(0,0,0))
            end
        end

        local shock = emitter:Add("particle/warp1_warp", pos)
        if shock then
            shock:SetDieTime(0.35)
            shock:SetStartAlpha(255)
            shock:SetEndAlpha(0)
            shock:SetStartSize(40)
            shock:SetEndSize(1400)
            shock:SetColor(255,255,255)
        end

        local ring = emitter:Add("particle/Particle_Ring_Blur", pos)
        if ring then
            ring:SetDieTime(0.5)
            ring:SetStartAlpha(255)
            ring:SetEndAlpha(0)
            ring:SetStartSize(1)
            ring:SetEndSize(1600)
            ring:SetColor(255,255,255)
        end

        emitter:Finish()
    end)

    function ENT:Draw()
        self:DrawModel()
    end
end
