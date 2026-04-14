AddCSLuaFile()

DEFINE_BASECLASS("base_wire_entity")

ENT.Type      = "anim"
ENT.PrintName = "Turret Ring"
ENT.Author    = "Person"
ENT.Category  = "P.H.W"
ENT.Spawnable = true

ENT.Model = "models/props_phx/wheels/metal_wheel1.mdl"

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(255)
            phys:Wake()
        end

        self.Active = 0
        self.InputPitch = nil
        self.InputYaw = nil
        self.RotateSpeed = 2
        self.HP = 150
        self.NextFX = 0

        self.Inputs = WireLib.CreateInputs(self, {
            "Active",
            "Pitch [ANGLE]",
            "Yaw [ANGLE]"
        })
    end

    function ENT:OnTakeDamage(dmg)
        self.HP = self.HP - dmg:GetDamage()
        if self.HP < 0 then self.HP = 0 end
    end

    function ENT:TriggerInput(name, val)
        if name == "Active" then
            self.Active = val
        elseif name == "Pitch" then
            self.InputPitch = val.p
        elseif name == "Yaw" then
            self.InputYaw = val.y
        end
    end

    function ENT:Think()
        local speed = self.RotateSpeed
        if self.HP <= 3 then speed = speed * 0.1 end

        if self.Active > 0 then
            local parent = self:GetParent()
            local parentAng = Angle(0,0,0)

            if IsValid(parent) then
                parentAng = parent:GetAngles()
            end

            local pitch = self.InputPitch or parentAng.p
            local yaw = self.InputYaw or parentAng.y

            local correctedPitch = pitch - parentAng.p
            local correctedYaw = yaw - parentAng.y

            local tgt = Angle(correctedPitch, correctedYaw, 0)
            local cur = self:GetLocalAngles()
            local new = LerpAngle(speed * FrameTime(), cur, tgt)

            self:SetLocalAngles(new)
        end

        if self.HP <= 3 and CurTime() > self.NextFX then
            local pos = self:GetPos()

            local ed = EffectData()
            ed:SetOrigin(pos)
            util.Effect("cball_explode", ed)

            local ed2 = EffectData()
            ed2:SetOrigin(pos)
            util.Effect("ManhackSparks", ed2)

            sound.Play("DoSpark", pos, 75, 100, 1)

            self.NextFX = CurTime() + 3.3
        end

        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
