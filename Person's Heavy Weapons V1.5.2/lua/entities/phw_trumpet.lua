AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type        = "anim"
ENT.Base        = "base_wire_entity"
ENT.PrintName   = "Jericho-Trompete"
ENT.Author      = "Person"
ENT.Spawnable   = true
ENT.Category    = "P.H.W"

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_lab/tpplug.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(100)
        end
        self.Active        = false
        self.LastInputTime = 0
        self.SirenLoop     = nil
        self.firing        = false
        self.Inputs = WireLib.CreateInputs(self, { "Fire" })
        self.Outputs = WireLib.CreateOutputs(self, { "Active" })
    end

    function ENT:OnRemove()
        if self.SirenLoop then
            self.SirenLoop:Stop()
            self.SirenLoop = nil
        end
    end

    function ENT:TriggerInput(name, value)
        if name == "Fire" then
            if value > 0 then
                self.Active = true
                self.LastInputTime = CurTime()
            end
        end
    end

    function ENT:Think()
        if CurTime() - self.LastInputTime > 0.2 then
            self.Active = false
        end
        WireLib.TriggerOutput(self, "Active", self.Active and 1 or 0)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) and self.Active then
            local speed = phys:GetVelocity():Length()
            local threshold = 300
            if speed > threshold then
                if not self.SirenLoop then
                    self.SirenLoop = CreateSound(self, "NPC_Manhack.EngineSound1")
                    self.SirenLoop:SetSoundLevel(9140)
                end
                if self.SirenLoop then
                    local frac = math.Clamp((speed - threshold) / 1000, 0, 1)
                    local vol  = Lerp(frac, 0.8, 1.2)
                    local pitch = math.floor(Lerp(frac, 90, 200))
                    self.SirenLoop:PlayEx(vol, pitch)
                end
            else
                if self.SirenLoop then
                    self.SirenLoop:FadeOut(1.5)
                end
            end
        else
            if self.SirenLoop then
                self.SirenLoop:FadeOut(1.5)
            end
        end
        self:NextThink(CurTime() + 0.05)
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
