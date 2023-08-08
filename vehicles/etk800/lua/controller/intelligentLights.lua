--Author: Niclas Ryge
--Some people like to say "don'T yOu DaRE uSe MY Code OR ElSe", but I am not a flaming narcissist.
--If you learn or gather anything from this, please take all you can. Never make something others have already done for you.
--Although, I'd like a shoutout if this turns out useful to you so I know if I helped someone :)

local M = {}
M.type = "auxiliary"

--Do this once to save on a few resources.
local fixedLog = math.log(1.5)


local currentValueLeft = 0
local currentValueRight = 0
local currentValueHighLeft = 0
local currentValueHighRight = 0


-- clamp function to make my life easier at the expense of your framerate
function math.clamp(low, n, high) return math.min(math.max(n, low), high) end


-- returns distance between player and target
-- - Includes square root so is computationally heavy. Use getSquaredDistance.
local function getDistance(player, target)
  return math.sqrt((target.x - player.x)^2 + (target.y - player.y)^2 + (target.z - player.z)^2)
end 

-- Identical to getDistance, only squared.
-- Far less computationally heavy.
-- - Argument 1: object 1 - Vec3
-- - Argument 2: object 2 - Vec3
-- - Returns squared distance as number
local function getSquaredDistance(player, target)
  return (target.x - player.x)^2 + (target.y - player.y)^2 + (target.z - player.z)^2
end 


--Makes the light smoothly walk along the steering angle instead of snapping around.
local function takeStep(targetValue, target, dt, currentValue, clampMin, clampMax, smoothness, override)

  if override ~= -1 then
    electrics.values[target] = override
    return targetValue
  else

    --Clamp the targetValue according to the min and max which allows for an offset to occur.
    local step = (math.clamp(targetValue, clampMin, clampMax) - currentValue) * dt * smoothness --5.2

    --local newValue = math.clamp(currentValue + step, clampMin, clampMax)
    --Testing if I can rely only on clamping the target value
    local newValue = currentValue+step

    --prevent the lights from turning off at 0 or very low values
    if newValue%360 < 0.01 and newValue%360 > -0.01 then
      electrics.values[target] = 0.01
    else
      electrics.values[target] = newValue % 360
    end
    return newValue
  end
end

--Determines if a light should be off based on the the value of the light plus the width (lOff, rOff),
-- And an angle to determine whether the angle is inside the lightsource or not.
local function determineOff(value,angle,abs, target, lOff, rOff) 
  if value+lOff > angle and value-rOff < angle and abs <= 40 then
    return 1
  else 
    return 0
  end
end

-- Returns relative object OBB
local function getOBBRelative(pos, dir, vehObj)

  local center = obj:getObjectCenterPosition(vehObj.id)

  local dirVec, dirVecUp = obj:getObjectDirectionVector(vehObj.id), obj:getObjectDirectionVectorUp(vehObj.id)
  local dirVecSide = vec3()

  dirVecSide:setCross(dirVecUp, dirVec)
  dirVecSide:normalize()
  dirVecSide:setScaled(obj:getObjectInitialWidth(vehObj.id)*0.5)
  dirVec:setScaled(obj:getObjectInitialLength(vehObj.id)*0.5)
  dirVecUp:setScaled(obj:getObjectInitialHeight(vehObj.id)*0.5)

  return dirVec, dirVecSide, dirVecUp
end


-- Returns whether a ray hits the intended object, or is blocked prematurely.
local function rayIntersection(pos, dir, vehObj)
  local center = obj:getObjectCenterPosition(vehObj.id)

  local dirVec, dirVecUp = obj:getObjectDirectionVector(vehObj.id), obj:getObjectDirectionVectorUp(vehObj.id)
  local dirVecSide = vec3()

  dirVecSide:setCross(dirVecUp, dirVec)
  dirVecSide:normalize()
  dirVecSide:setScaled(obj:getObjectInitialWidth(vehObj.id)*0.5)
  dirVec:setScaled(obj:getObjectInitialLength(vehObj.id)*0.5)
  dirVecUp:setScaled(obj:getObjectInitialHeight(vehObj.id)*0.5)

                                      --Inefficient
  local rayLen = obj:castRayStatic(pos, dir, math.sqrt(vehObj.distance))
  --print(rayLen)
  --print(pos)


  -- returns: min distance and max distance of the OBB, not whether or not we are actually hitting the object.
  local resultmin, resultmax = intersectsRay_OBB(pos, dir, center, dirVec, dirVecSide, dirVecUp)
  --This is essentially pointless because we are aiming at the center, not a particular direction of travel - but we still 
  --need the value for comparing the raylength to.
  
  --return math.min(rayLen, math.max(resultmin, 0)) -- ~= math.huge

  -- I am the king of cringe edgecases.
  -- Let us assume that it is impossible for the ray (which is wrong) to never be shorter than the bounding box ray hit 
  -- as we are aiming for the vehicle center. Under that assumption; If the ray is shorter, it must be because we are hitting something
  -- unintended. Thusly, we create:

  if rayLen < (math.max(resultmin, 0)) then
    return false
  else 
    return true
  end
end


local function updateGFX(dt)
  local lowbeam = electrics.values.lowbeam
  local highbeam = electrics.values.highbeam
  local lowhighbeam = electrics.values.lowhighbeam
  local reverse = electrics.values.reverse
  local steering = input.steering
  local wheelspeed = electrics.values.wheelspeed
  local targetValue = 0
  local hiTargetLeft = 0
  local hiTargetRight = 0
  local hiOffsetLeft = 0
  local hiOffsetRight = 0
  local hiOffsetDirectional = 0
  local offset = 0

  local objPos = 0
  local playerPos = 0
  local playerDir = 0
  local directionToTarget = 0
  local angle = 0
  local hiSmoothR, hiSmoothL = 8, 8
  local distance = 0
  local crossproduct = 0
  local dotproduct = 0 
  local absAngle = 0
  local overrideLeft = -1
  local overrideRight = -1
  local objectArr = {}

  
  -- This should obviously be inside the if-statement to save on performance, but putting it here much improves the look of suddenly turning on the lights.
  -- Set this way because we dont want the angle to be calculated when standing still, and -16 is good for the steering angle.
  targetValue = (steering * -16) * (math.clamp(math.log(math.min(wheelspeed, 50)) / fixedLog, 0, 100))
  hiTargetLeft = targetValue
  hiTargetRight = targetValue
  local carProcessed = false
  objectArr = {}
  if lowhighbeam > 0 and electrics.values.ignitionLevel > 0 then
    if reverse == 0 then
      --This is where it should be
    else
      targetValue = 0
    end

    if highbeam > 0 then
      offset = 12.5
      
      for objId, v in pairs(mapmgr.getObjects()) do
        --print(intersectsRay_OBB())
        --objectId refers to the object this controller belongs to.
        if objId ~= objectId then
        
          objPos = v.pos
          
          --Dont use maybe.
          --playerPos = mapmgr.objects[objectId].pos
          playerDir = mapmgr.objects[objectId].dirVec 
          playerPos = obj:getObjectCenterPosition(objectId)

          distance = getSquaredDistance(mapmgr.objects[objectId].pos, v.pos)

          if distance < 180^2 then
            
            directionToTarget = vec3(objPos.x - playerPos.x, objPos.y - playerPos.y, objPos.z - playerPos.z)
            directionToTarget:normalize()

            --This should be self-explainatory
            crossproduct = directionToTarget:cross(playerDir)
            dotproduct = directionToTarget:dot(playerDir)

            --We need absAngle because angle would also be activated behind the car.
            angle = (math.deg(math.asin(crossproduct.z))+0.5)*-1
            absAngle = math.deg(math.acos(dotproduct))


            if angle < 40 and angle > -40 and absAngle <= 40 and absAngle >=-40 then            

              --Add angle to the vehicle's table
              v.angle = angle
              v.absAngle = absAngle
              v.id = objId
              v.distance = distance
              v.targDir = directionToTarget
              objectArr[v] = distance

            end
          end
        end
      end

      --Determining the closest vehicle
      local min = math.huge
      local closest = nil
      for i, v in pairs(objectArr) do
        if min > math.min(min, v) then
          min = math.min(min, v)
          closest = i
        end
      end
      
      local leftOff, rightOff, counter, visCounter  = 0,0,0,0

      for v, distance in pairs(objectArr) do

        local frontpos = playerPos + (playerDir*(obj:getObjectInitialLength(objectId)*0.5))

        --Should include up vectors too. 
        if v.angle < 40 and v.angle > -40 and v.absAngle <= 40 and v.absAngle >=0 and rayIntersection(frontpos, v.targDir, v) then
          visCounter = visCounter + 1
          --Only process the closest vehicle, because I haven't come up with a way to prioritize targets yet.
          

          if v == closest then

            if v.angle > -10 and v.angle < 15 and v == closest then
            
              hiTargetRight = v.angle
              hiOffsetRight = 10
              hiOffsetDirectional = 15
              --override value to follow the blinded car
              hiTargetRight = v.angle
              hiSmoothR = 30
            end

            if v.angle < 10 and v.angle > -15 and v == closest then

              hiTargetLeft = v.angle
              hiOffsetLeft = 10
              hiOffsetDirectional = 15
              --override value to follow the blinded car
              hiTargetLeft = v.angle
              hiSmoothL = 30
            end
            --Override headlights
            carProcessed = true
            currentValueHighLeft = takeStep(hiTargetLeft + hiOffsetLeft, leftHigh, dt, currentValueHighLeft, -15+hiOffsetDirectional, 15+hiOffsetDirectional, hiSmoothL, overrideLeft)
            currentValueHighRight = takeStep(hiTargetRight - hiOffsetRight, rightHigh, dt, currentValueHighRight, -15-hiOffsetDirectional, 15-hiOffsetDirectional, hiSmoothR, overrideRight)
          end
          
          --Override to turn off lights when object is inside the cone (Not dynamic enough)
        --leftOff = leftOff + determineOff(currentValueHighLeft, v.angle, v.absAngle, leftHigh, 10, 8)
        --rightOff = rightOff + determineOff(currentValueHighRight, v.angle, v.absAngle, rightHigh, 8, 10)

        end

        --sshhh
        counter = counter + 1

      end 

      --If the headlights aren't overridden, just use them normally
      if not carProcessed then
        currentValueHighLeft = takeStep(hiTargetLeft, leftHigh, dt, currentValueHighLeft, -15, 15, hiSmoothL, overrideLeft)
        currentValueHighRight = takeStep(hiTargetRight, rightHigh, dt, currentValueHighRight, -15, 15, hiSmoothR, overrideRight)
      end
      if leftOff > 0 then
        electrics.values[leftHigh] = 0
      end
      if rightOff > 0 then
        electrics.values[rightHigh] = 0
      end

      print("Cars processed: " .. counter .." - of which visible: " .. visCounter )
    
    else
      offset = 0
      electrics.values[leftHigh] = 0
      electrics.values[rightHigh] = 0

      --This is only possible because the lights are already on.
      --It keeps the highbeams in the place they would otherwise be, so that when flashing them, it doesn't fly around the screen.
      currentValueHighLeft = targetValue
      currentValueHighRight = targetValue
    end
    -- Static  clamps for now
    currentValueLeft = takeStep(targetValue + offset, left, dt, currentValueLeft, -20 + (offset * 2), 20, 8, -1)
    currentValueRight = takeStep(targetValue - offset, right, dt, currentValueRight, -20, 20 - (offset * 2), 8, -1)
  else
    electrics.values[left] = 0
    electrics.values[right] = 0
    electrics.values[leftHigh] = 0
    electrics.values[rightHigh] = 0

    currentValueLeft = targetValue
    currentValueRight = targetValue
  end
end

--Please remember: approximated highbeam cover distance = 40° in either direction when centered, but extend 15° to either side
--Please remember: approximated range of highbeams ~ 200m
local function init(jbeamData)
  left = "cornerLeft"
  right = "cornerRight"
  leftHigh = "leftHigh"
  rightHigh = "rightHigh"

  highbeams = "beams"
  electrics.values[left] = 0
  electrics.values[right] = 0
  electrics.values[leftHigh] = 0
  electrics.values[rightHigh] = 0

  
end

M.init = init
M.updateGFX = updateGFX

return M
