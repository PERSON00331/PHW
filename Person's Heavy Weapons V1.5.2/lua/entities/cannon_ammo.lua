AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Universal Ammo"
ENT.Author = "Person"
ENT.Spawnable = true
ENT.Category = "P.H.W"

if SERVER then
    util.AddNetworkString("Ammo_FizzParticles")

    function ENT:Initialize()
        self:SetModel("models/props/de_prodigy/ammo_can_02.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self:SetModelScale(1, 0)

    end
function ENT:IgniteAmmo()
    if not self.Ignited then
        self.Ignited = true

        if math.random(1, 3) == 2 then
            -- explode
            self:StartExplosionSequence()
        else
            self:EmitSound("buttons/button10.wav", 75, 100, 1, CHAN_AUTO)
        end
    end
end

    function ENT:StartExplosionSequence()
        if self.Exploding then return end
        self.Exploding = true

        net.Start("Ammo_FizzParticles")
        net.WriteEntity(self)
        net.Broadcast()

        timer.Simple(5, function()
            if IsValid(self) then
                self:DoExplosion()
            end
        end)
    end

    function ENT:DoExplosion()
        local pos = self:GetPos()

        local effectdata = EffectData()
        effectdata:SetOrigin(pos)
        util.Effect("Explosion", effectdata)
        sound.Play("ambient/explosions/explode_4.wav", pos, 100, 100, 1)

        local radius = 250
        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent:GetClass() == "prop_physics" then
                constraint.RemoveConstraints(ent, "Weld")
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:EnableMotion(true)
                    phys:Wake()
                end
            end
        end

        self:Remove()
    end
end

if CLIENT then
    local FizzState = {}

    local function StopFizz(idx)
        local state = FizzState[idx]
        if not state then return end

        local timerID = state.timerID
        if timerID and timer.Exists(timerID) then
            timer.Remove(timerID)
        end

        local emitter = state.emitter
        if emitter then
            pcall(function() emitter:Finish() end)
        end

        FizzState[idx] = nil
    end

    net.Receive("Ammo_FizzParticles", function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        local idx = ent:EntIndex()
        StopFizz(idx)

        local emitter = ParticleEmitter(ent:GetPos())
        local timerID = "AmmoFizz_" .. idx

        FizzState[idx] = { emitter = emitter, timerID = timerID, ent = ent }

        timer.Create(timerID, 0.05, 0, function()
            local state = FizzState[idx]
            if not state then
                timer.Remove(timerID)
                return
            end

            local e = state.ent
            local em = state.emitter
            if not IsValid(e) or not em then
                StopFizz(idx)
                return
            end

            local pos = e:GetPos() + VectorRand() * 12 + Vector(0,0,10)

            local p = em:Add("effects/spark", pos)
            if p then
                p:SetVelocity(VectorRand() * 111)
                p:SetDieTime(0.8)
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(15)
                p:SetEndSize(0)
                p:SetColor(255, 220, 80)
            end

            local s = em:Add("particle/particle_smokegrenade", pos)
            if s then
                s:SetVelocity(VectorRand() * 15 + Vector(0,0,10))
                s:SetDieTime(math.Rand(1.6, 2.2))
                s:SetStartAlpha(111)
                s:SetEndAlpha(0)
                s:SetStartSize(math.Rand(6, 10))
                s:SetEndSize(math.Rand(55, 99))
                s:SetRoll(math.Rand(0, 360))
                s:SetColor(180, 180, 180)
                s:SetAirResistance(40)
            end
        end)
    end)

    -- clean up if the ammo entity is removed clientside
    function ENT:OnRemove()
        local idx = self:EntIndex()
        StopFizz(idx)
    end

    function ENT:Draw()
        self:DrawModel()
    end
end
