require "/tech/doubletap.lua"

function init()
  self.airDashing = false
  self.dashDirection = 0
  self.dashTimer = 0
  self.dashCooldownTimer = 0
  self.rechargeEffectTimer = 0
  self.dashControlForce = config.getParameter("dashControlForce")
  self.dashSpeed = config.getParameter("dashSpeed")
  self.dashDuration = config.getParameter("dashDuration")
  self.dashCooldown = config.getParameter("dashCooldown")
  self.groundOnly = config.getParameter("groundOnly")
  self.stopAfterDash = config.getParameter("stopAfterDash")
  self.rechargeDirectives = config.getParameter("rechargeDirectives", "?fade=CCCCFFFF=0.25")
  self.rechargeEffectTime = config.getParameter("rechargeEffectTime", 0.1)

  self.doubleTap = DoubleTap:new({"left", "right"}, config.getParameter("maximumDoubleTapTime"), function(dashKey)
      if self.dashTimer == 0
          and self.dashCooldownTimer == 0
          and groundValid()
          and not mcontroller.crouching()
          and not status.statPositive("activeMovementAbilities") then

        startDash(dashKey == "left" and -1 or 1)
      end
    end)

  animator.setAnimationState("dashing", "off")
end

function uninit()
  status.clearPersistentEffects("movementAbility")
  tech.setParentDirectives()
end

function applyTechBonus()
  self.dashBonus = 1 + status.stat("dashtechBonus") -- apply bonus from certain items and armor
  self.dodgetechBonus = 0 + status.stat("dodgetechBonus") -- apply bonus to defense from items and armor
  self.dashControlForce = config.getParameter("dashControlForce") * self.dashBonus
  self.dashSpeed = config.getParameter("dashSpeed") * self.dashBonus
end

function update(args)
  applyTechBonus()
  if self.dashCooldownTimer > 0 then
    self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - args.dt)
    if self.dashCooldownTimer == 0 then
      self.rechargeEffectTimer = self.rechargeEffectTime
      tech.setParentDirectives(self.rechargeDirectives)
      animator.playSound("recharge")
    end
  end

  if self.rechargeEffectTimer > 0 then
    self.rechargeEffectTimer = math.max(0, self.rechargeEffectTimer - args.dt)
    if self.rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end

  self.doubleTap:update(args.dt, args.moves)

  if self.dashTimer > 0 then
    mcontroller.controlApproachVelocity({self.dashSpeed * self.dashDirection, 0}, self.dashControlForce)
    mcontroller.controlMove(self.dashDirection, true)

    if self.airDashing then
      mcontroller.setYVelocity(0)
    end
    mcontroller.controlModifiers({jumpingSuppressed = true})

    animator.setFlipped(mcontroller.facingDirection() == -1)

    self.dashTimer = math.max(0, self.dashTimer - args.dt)

    if self.dashTimer == 0 then
      endDash()
    end
  end
end

function groundValid()
  return mcontroller.groundMovement() or not self.groundOnly
end

function startDash(direction)
  self.dashDirection = direction
  self.dashTimer = self.dashDuration
  self.airDashing = not mcontroller.groundMovement()
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  animator.playSound("startDash")
  animator.setAnimationState("dashing", "on")
  animator.setParticleEmitterActive("dashParticles", true)
  -- defense bonus is applied if the player has the relevant stat. Otherwise we apply the basic small boost granted by the default tech
  if self.dodgetechBonus > 0.01 then
    status.setPersistentEffects("dodgeDefenseBoost", {{stat = "protection", effectiveMultiplier = (1 + self.dodgetechBonus)}})
  else
    status.addEphemeralEffect(config.getParameter("dodgeboost"))
  end

end

function endDash()
  status.clearPersistentEffects("movementAbility")
  status.clearPersistentEffects("dodgeDefenseBoost")
  if self.stopAfterDash then
    local movementParams = mcontroller.baseParameters()
    local currentVelocity = mcontroller.velocity()
    if math.abs(currentVelocity[1]) > movementParams.runSpeed then
      mcontroller.setVelocity({movementParams.runSpeed * self.dashDirection, 0})
    end
    mcontroller.controlApproachXVelocity(self.dashDirection * movementParams.runSpeed, self.dashControlForce)
  end
  self.dashCooldownTimer = self.dashCooldown
  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticles", false)
end
