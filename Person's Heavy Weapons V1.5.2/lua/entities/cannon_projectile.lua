AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Cannon Projectile"
ENT.Author = "Person"
ENT.Spawnable = false

if SERVER then
    util.AddNetworkString("Cannon_Poof")
    util.AddNetworkString("Cannon_Sparks")

    function ENT:Initialize()
        self:SetModel("models/Items/AR2_Grenade.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        util.SpriteTrail(self, 0, Color(200,200,200), false, 8, 1, 0.5, 1/(8+1)*0.5, "trails/smoke.vmt")

        local glow = ents.Create("env_sprite")
        glow:SetKeyValue("model", "sprites/light_glow02.vmt")
        glow:SetKeyValue("scale", "0.8")
        glow:SetKeyValue("rendermode", "5")
        glow:SetKeyValue("rendercolor", "255 150 50")
        glow:SetPos(self:GetPos())
        glow:SetParent(self)
        glow:Spawn()

        self.Armed = false
        self.LastPos = self:GetPos()

        timer.Simple(0.5, function()
            if IsValid(self) then
                self.Armed = true
            end
        end)
    end

    function ENT:PhysicsCollide(data, phys)
        local hitpos = data.HitPos
        local hitent = data.HitEntity
        local vel = data.OurOldVelocity:GetNormalized()
        local normal = data.HitNormal:GetNormalized()
        local dot = math.abs(vel:Dot(normal))
        local chance = 25
        if dot < 0.5 then chance = 20 end
        if dot < 0.2 then chance = 10 end

        if math.random(1, chance) == 1 then
            local bounce = -vel + normal * 2
            phys:SetVelocity(bounce * phys:GetVelocity():Length() * -55.8)
            self:EmitSound("physics/metal/metal_solid_impact_bullet1.wav", 75, 100)
            net.Start("Cannon_Sparks")
            net.WriteVector(hitpos)
            net.WriteVector(vel)
            net.Broadcast()
            return
        end

        local blastradius = 0.1
        local blastdamage = 100

        if IsValid(hitent) and hitent.IsPHWArmor then
            local dmg = math.random(74, 98)
            hitent.ArmorHP = math.max(0, (hitent.ArmorHP or 0) - dmg)
            hitent:EmitSound("physics/metal/metal_box_impact_hard1.wav", 70, 100)

            net.Start("Cannon_Sparks")
            net.WriteVector(hitpos)
            net.WriteVector(vel)
            net.Broadcast()

            if hitent.ArmorHP <= 0 then
                hitent:EmitSound("physics/metal/metal_sheet_impact_hard2.wav", 80, 95)
                hitent:Remove()
            end
        else
            sound.Play("ambient/explosions/explode_4.wav", hitpos, 100, 100, 1)
            sound.Play("weapons/explode3.wav", hitpos, 90, 100, 0.7)
            self:DoExplosionEffect(hitpos, blastradius, blastdamage, true)
        end

        self:Remove()
    end

    function ENT:Think()
        if self.Armed then
            local pos = self:GetPos()
            local last = self.LastPos

            local tr = util.TraceHull({
                start = last,
                endpos = pos,
                mins = Vector(-7,-7,-7),
                maxs = Vector(11,11,11),
                filter = self
            })

            if tr.Hit and IsValid(tr.Entity) then
                local ent = tr.Entity
                local hitpos = tr.HitPos
                local vel = (pos - last):GetNormalized()

                if ent.IsPHWArmor then
                    local dmg = math.random(74, 98)
                    ent.ArmorHP = math.max(0, (ent.ArmorHP or 0) - dmg)
                    ent:EmitSound("physics/metal/metal_box_impact_hard1.wav", 70, 100)

                    net.Start("Cannon_Sparks")
                    net.WriteVector(hitpos)
                    net.WriteVector(vel)
                    net.Broadcast()

                    if ent.ArmorHP <= 0 then
                        ent:EmitSound("physics/metal/metal_sheet_impact_hard2.wav", 80, 95)
                        ent:Remove()
                    end

                    self:Remove()
                    return
                end

                sound.Play("ambient/explosions/explode_4.wav", hitpos, 100, 100, 1)
                sound.Play("weapons/explode3.wav", hitpos, 90, 100, 0.7)
                self:DoExplosionEffect(hitpos, 0.1, 100, true)
                self:Remove()
                return
            end

            self.LastPos = pos
        end

        self:NextThink(CurTime())
        return true
    end

    function ENT:DoExplosionEffect(pos, blastradius, blastdamage, dounfreeze)
        local effectdata = EffectData()
        effectdata:SetOrigin(pos)
        util.Effect("Explosion", effectdata)

        local attacker = IsValid(self:GetOwner()) and self:GetOwner() or self
        util.BlastDamage(self, attacker, pos, blastradius, blastdamage)

        if dounfreeze then
            for _, ent in ipairs(ents.FindInSphere(pos, blastradius)) do
                if IsValid(ent) and ent:GetClass() == "prop_physics" then
                    constraint.RemoveConstraints(ent, "Weld")
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(true)
                        phys:Wake()
                    end
                end
            end
        end

        local igniteradius = 3
        for _, ent in ipairs(ents.FindInSphere(pos, igniteradius)) do
            if IsValid(ent) then
                if ent:IsPlayer() or ent:IsNPC() then
                    ent:Ignite(5, 0)
                elseif ent:GetClass() == "prop_physics" then
                    ent:Ignite(10, 0)
                elseif ent:GetClass() == "cannon_ammo" then
                    if ent.IgniteAmmo then
                        ent:IgniteAmmo()
                    else
                        ent:Ignite(10, 0)
                    end
                end
            end
        end

        net.Start("Cannon_Poof")
        net.WriteVector(pos)
        net.Broadcast()
    end
end

if CLIENT then
    net.Receive("Cannon_Poof", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        for i = 1, 15 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * 350 + Vector(0,0,111))
                p:SetDieTime(math.Rand(11.6, 13.2))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(10, 20))
                p:SetEndSize(math.Rand(355, 455))
                p:SetRoll(math.Rand(0, 360))
                p:SetRollDelta(math.Rand(-2, 2))
                p:SetColor(200, 200, 200)
                p:SetAirResistance(85)
                p:SetGravity(Vector(0, 0, -55))
            end
        end

        local warp = emitter:Add("particle/warp1_warp", pos)
        if warp then
            warp:SetDieTime(1)
            warp:SetStartAlpha(255)
            warp:SetEndAlpha(0)
            warp:SetStartSize(155)
            warp:SetEndSize(654)
            warp:SetColor(255,255,255)
        end

        local ring = emitter:Add("particle/Particle_Ring_Blur", pos)
        if ring then
            ring:SetDieTime(0.4)
            ring:SetStartAlpha(180)
            ring:SetEndAlpha(0)
            ring:SetStartSize(20)
            ring:SetEndSize(455)
            ring:SetColor(255,255,255)
        end

        local core = emitter:Add("sprites/orangecore2", pos)
        if core then
            core:SetDieTime(0.5)
            core:SetStartAlpha(255)
            core:SetEndAlpha(0)
            core:SetStartSize(40)
            core:SetEndSize(80)
            core:SetColor(255,150,50)
        end

        emitter:Finish()
    end)

    net.Receive("Cannon_Sparks", function()
        local pos = net.ReadVector()
        local dir = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        for i = 1, 45 do
            local p = emitter:Add("particles/fire_glow", pos)
            if p then
                local spread = dir + VectorRand() * 1.2
                p:SetVelocity(spread:GetNormalized() * math.Rand(150, 300))
                p:SetDieTime(math.Rand(0.2, 3.5))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(2, 15))
                p:SetEndSize(0)
                p:SetRoll(math.Rand(0, 360))
                p:SetColor(255, 180, 80)
            end
        end

        emitter:Finish()
    end)
end
