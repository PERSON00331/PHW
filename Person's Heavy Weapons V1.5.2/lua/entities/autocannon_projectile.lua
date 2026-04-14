AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Autocannon Projectile"
ENT.Author = "Person"
ENT.Spawnable = false

if SERVER then
    util.AddNetworkString("AutoCannon_Poof")
    util.AddNetworkString("AutoCannon_Sparks")

    function ENT:Initialize()
        self:SetModel("models/Items/AR2_Grenade.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        util.SpriteTrail(self, 0, Color(233,233,233), false, 5, 1, 0.5, 1/(8+1)*0.2, "trails/smoke.vmt")

        local glow = ents.Create("env_sprite")
        glow:SetKeyValue("model", "sprites/light_glow02.vmt")
        glow:SetKeyValue("scale", "1.1")
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

        local chance = 15
        if dot < 0.6 then chance = 10 end
        if dot < 0.3 then chance = 5 end

        if math.random(1, chance) == 1 then
            local deflectdir = normal
            local hitphys = IsValid(hitent) and hitent:GetPhysicsObject() or nil
            if IsValid(hitphys) then
                deflectdir = Vector(0, 0, 50)
            end

            local bounce = -vel + deflectdir * 2
            phys:SetVelocity(bounce * phys:GetVelocity():Length() * -150.8)
            self:EmitSound("physics/metal/metal_solid_impact_bullet1.wav", 75, 100)

            net.Start("AutoCannon_Sparks")
            net.WriteVector(hitpos)
            net.WriteVector(vel)
            net.Broadcast()
            return
        end

        local blastradius = 0.1
        local blastdamage = 40

        if IsValid(hitent) and hitent.IsPHWArmor then
            local dmg = math.random(5, 25)
            hitent.ArmorHP = math.max(0, (hitent.ArmorHP or 0) - dmg)
            hitent:EmitSound("physics/metal/metal_box_impact_hard1.wav", 70, 100)

            net.Start("AutoCannon_Sparks")
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
                mins = Vector(-5,-5,-5),
                maxs = Vector(15,15,15),
                filter = self
            })

            if tr.Hit and IsValid(tr.Entity) then
                local ent = tr.Entity
                local hitpos = tr.HitPos
                local vel = (pos - last):GetNormalized()

                if ent.IsPHWArmor then
                    local dmg = math.random(5, 25)
                    ent.ArmorHP = math.max(0, (ent.ArmorHP or 0) - dmg)
                    ent:EmitSound("physics/metal/metal_box_impact_hard1.wav", 70, 100)

                    net.Start("AutoCannon_Sparks")
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
                self:DoExplosionEffect(hitpos, 0.1, 40, true)
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
                    ent:Ignite(2, 0)
                elseif ent:GetClass() == "prop_physics" then
                    ent:Ignite(3, 0)
                elseif ent:GetClass() == "cannon_ammo" then
                    if ent.IgniteAmmo then ent:IgniteAmmo() end
                elseif ent:GetClass() == "armor_plate1" then
                    ent:Ignite(2, 0)
                elseif ent:GetClass() == "phw_fuel" then
                    if ent.PHWFuel_FireStart then
                        ent:PHWFuel_FireStart()
                    else
                        ent:Ignite(3, 0)
                    end
                end
            end
        end

        net.Start("AutoCannon_Poof")
        net.WriteVector(pos)
        net.Broadcast()
    end
end

if CLIENT then
    net.Receive("AutoCannon_Poof", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        for i = 1, 20 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * 864 + Vector(0,0,50))
                p:SetDieTime(math.Rand(4.4, 5.5))
                p:SetStartAlpha(188)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(33, 35.7))
                p:SetEndSize(math.Rand(84, 85))
                p:SetRoll(math.Rand(0, 360))
                p:SetRollDelta(math.Rand(-2, 1))
                p:SetColor(220, 220, 220)
                p:SetAirResistance(255)
                p:SetGravity(Vector(0, 0, 35))
            end
        end

        local warp = emitter:Add("particle/warp1_warp", pos)
        if warp then
            warp:SetDieTime(0.5)
            warp:SetStartAlpha(200)
            warp:SetEndAlpha(0)
            warp:SetStartSize(80)
            warp:SetEndSize(444)
            warp:SetColor(255,255,255)
        end

        local ring = emitter:Add("particle/Particle_Ring_Blur", pos)
        if ring then
            ring:SetDieTime(0.3)
            ring:SetStartAlpha(150)
            ring:SetEndAlpha(0)
            ring:SetStartSize(15)
            ring:SetEndSize(777)
            ring:SetColor(255,255,255)
        end

        local core = emitter:Add("sprites/orangecore2", pos)
        if core then
            core:SetDieTime(0.3)
            core:SetStartAlpha(255)
            core:SetEndAlpha(0)
            core:SetStartSize(20)
            core:SetEndSize(40)
            core:SetColor(255,150,50)
        end

        emitter:Finish()
    end)

    net.Receive("AutoCannon_Sparks", function()
        local pos = net.ReadVector()
        local dir = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        for i = 1, 20 do
            local p = emitter:Add("particles/fire_glow", pos)
            if p then
                local spread = dir + VectorRand() * 0.5
                p:SetVelocity(spread:GetNormalized() * math.Rand(100, 200))
                p:SetDieTime(math.Rand(0.2, 1.0))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(2, 6))
                p:SetEndSize(0)
                p:SetRoll(math.Rand(0, 360))
                p:SetColor(255, 180, 80)
            end
        end

        emitter:Finish()
    end)
end
