AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Aerial Fuel"
ENT.Author = "Person"
ENT.Spawnable = true
ENT.Category = "P.H.W"

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "OnFire")
end

if SERVER then
    util.AddNetworkString("PHWFuel_FireStart")
    util.AddNetworkString("PHWFuel_FireStop")
    util.AddNetworkString("PHWFuel_Explode")
    util.AddNetworkString("PHWFuel_FizzParticles")

    function ENT:Initialize()
        self:SetModel("models/xqm/cylinderx2huge.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(15)
        end

        self:SetModelScale(1, 0)
        self:SetOnFire(false)
        self.ExplodeTime = nil
        self.Ignited = false
    end

    function ENT:Think()
        if self:IsOnFire() and not self.Ignited then
            self.Ignited = true

            if math.random(1, 3) == 2 then
                self:StartFizzSequence()
            else
                self:StartExplosionCountdown()
            end
        end

        if self.ExplodeTime and CurTime() >= self.ExplodeTime then
            self:Explode()
        end

        self:NextThink(CurTime())
        return true
    end

    function ENT:StartExplosionCountdown()
        self:SetOnFire(true)
        self.ExplodeTime = CurTime() + 6

        net.Start("PHWFuel_FireStart")
            net.WriteEntity(self)
        net.Broadcast()
    end

    function ENT:StartFizzSequence()
        net.Start("PHWFuel_FizzParticles")
            net.WriteEntity(self)
        net.Broadcast()

        timer.Simple(5, function()
            if IsValid(self) then
                self:Explode()
            end
        end)
    end

    function ENT:Explode()
        local pos = self:GetPos()

        util.BlastDamage(self, self, pos, 250, 200)
        sound.Play("ambient/explosions/explode_4.wav", pos, 100, 100, 1)

        for _, ent in pairs(ents.FindInSphere(pos, 15)) do
            if IsValid(ent) and constraint.HasConstraints(ent) then
                constraint.RemoveAll(ent)
            end
        end

        net.Start("PHWFuel_Explode")
            net.WriteVector(pos)
        net.Broadcast()

        net.Start("PHWFuel_FireStop")
            net.WriteEntity(self)
        net.Broadcast()

        self:Remove()
    end
end

if CLIENT then
    local ActiveFires = {}
    local FizzState = {}

    net.Receive("PHWFuel_FireStart", function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end
        ActiveFires[ent] = {
            emitter = ParticleEmitter(ent:GetPos()),
            nextParticle = 0
        }
    end)

    net.Receive("PHWFuel_FireStop", function()
        local ent = net.ReadEntity()
        if ActiveFires[ent] then
            if ActiveFires[ent].emitter then
                ActiveFires[ent].emitter:Finish()
            end
            ActiveFires[ent] = nil
        end
    end)

    net.Receive("PHWFuel_Explode", function()
        local pos = net.ReadVector()
        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        for i = 1, 25 do
            local p = emitter:Add("particle/particle_smokegrenade", pos)
            if p then
                p:SetVelocity(VectorRand() * math.Rand(200, 400))
                p:SetDieTime(math.Rand(5.5, 6.5))
                p:SetStartAlpha(220)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(25, 35))
                p:SetEndSize(math.Rand(270, 290))
                p:SetColor(33, 33, 33)
            end
        end

        emitter:Finish()
    end)

    net.Receive("PHWFuel_FizzParticles", function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        local idx = ent:EntIndex()
        local emitter = ParticleEmitter(ent:GetPos())
        local timerID = "PHWFuelFizz_" .. idx

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
                timer.Remove(timerID)
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
                s:SetDieTime(math.Rand(4.6, 5.2))
                s:SetStartAlpha(255)
                s:SetEndAlpha(0)
                s:SetStartSize(math.Rand(6, 10))
                s:SetEndSize(math.Rand(355, 399))
                s:SetColor(180, 180, 180)
                s:SetAirResistance(40)
            end
        end)
    end)

    hook.Add("Think", "PHWFuel_FireParticles", function()
        for ent, data in pairs(ActiveFires) do
            if not IsValid(ent) then
                if data.emitter then data.emitter:Finish() end
                ActiveFires[ent] = nil
                continue
            end

            if data.nextParticle <= CurTime() then
                data.nextParticle = CurTime() + 0.1
                local origin = ent:GetPos()
                if data.emitter then
                    data.emitter:SetPos(origin)
                    local p = data.emitter:Add("particle/particle_smokegrenade", origin)
                    if p then
                        p:SetVelocity(VectorRand() * 11 + Vector(0,0,50))
                        p:SetDieTime(math.Rand(2.0, 3.0))
                        p:SetStartAlpha(255)
                        p:SetEndAlpha(0)
                        p:SetStartSize(math.Rand(15, 25))
                        p:SetEndSize(math.Rand(260, 280))
                        p:SetColor(20, 20, 20)
                    end
                end
            end
        end
    end)

    function ENT:OnRemove()
        local idx = self:EntIndex()
        local state = FizzState[idx]
        if state then
            if state.emitter then state.emitter:Finish() end
            if state.timerID and timer.Exists(state.timerID) then
                timer.Remove(state.timerID)
            end
            FizzState[idx] = nil
        end
    end

    function ENT:Draw()
        self:DrawModel()
    end
end
