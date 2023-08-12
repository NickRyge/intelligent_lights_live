-- Processing the lights
if lowhighbeam > 0 and electrics.values.ignitionLevel > 0 then

    if electrics.values.intelligence > 0 then
        if reverse == 0 then targetValue = (steering * -16) * (math.clamp(math.log(math.min(wheelspeed, 50)) / fixedLog, 0, 100)) else targetValue = 0 end

        -- Handle intelligent lighting in here

        -- If highbeams are on, react to them - These influence the mode of the lowbeams.
        -- should lights have a "mode" attribute?

        if electrics.values.intelligence == 2 then
            
            -- Populate and determine target
            objectArr, playerDir, playerPos = populateVehicles()
            local closest = determineNearest(objectArr)

            for v, distance in pairs(objectArr) do

                local frontpos = playerPos + (playerDir*(obj:getObjectInitialLength(objectId)*0.5))
      
                --Should include up vectors too. 
                if v.angle < 40 and v.angle > -40 and v.absAngle <= 40 and v.absAngle >=0 and rayIntersection(frontpos, v.targDir, v) then
                  visCounter = visCounter + 1
                  --Only process the closest vehicle, because I haven't come up with a way to prioritize targets yet.
      
                  if v == closest then
                    
                    targetRelativeOffset = (getTargetRelativeAngleSize(playerPos, "dir", v)*fixedLog)+10
      
                    if v.angle > -10 and v.angle < 15 and v == closest then
                    
                      hiTargetRight = v.angle
                      hiOffsetRight = targetRelativeOffset
                      hiOffsetDirectional = 15
                      --override value to follow the blinded car
                      hiTargetRight = v.angle
                      hiSmoothR = 30
                    end
      
                    if v.angle < 10 and v.angle > -15 and v == closest then
      
                      hiTargetLeft = v.angle
                      hiOffsetLeft = targetRelativeOffset
                      hiOffsetDirectional = 15
                      --override value to follow the blinded car
                      hiTargetLeft = v.angle
                      hiSmoothL = 30
                    end
                    --Override headlights
                    carProcessed = true
                    --currentValueHighLeft = takeStep(hiTargetLeft + hiOffsetLeft, leftHigh, dt, currentValueHighLeft, -15+hiOffsetDirectional, 15+hiOffsetDirectional, hiSmoothL, overrideLeft)
                    --currentValueHighRight = takeStep(hiTargetRight - hiOffsetRight, rightHigh, dt, currentValueHighRight, -15-hiOffsetDirectional, 15-hiOffsetDirectional, hiSmoothR, overrideRight)
                  else
                    --Is this neccessary?
                    targetRelativeOffset = 0 
                  end
                  
                
                  --Override to turn off lights when object is inside the cone (Not dynamic enough)
                leftOff = leftOff + determineOff(currentValueHighLeft, v.angle, v.absAngle, leftHigh, 12, 10)
                rightOff = rightOff + determineOff(currentValueHighRight, v.angle, v.absAngle, rightHigh, 10, 12)
      
                end
                counter = counter + 1
      
            end 

            print("Cars processed: " .. counter .." - of which visible: " .. visCounter )


        else
            -- if only 1 intelligence
            hiTargetLeft, hiTargetRight = targetValue,targetValue
            hiOffsetLeft, hiOffsetRight = 0, 0

        end


    else

        -- Uninentelligent lighting here. 
        -- Ideally the lowbeams should still move whenever the highbeamns are turned on.
        -- The highbeams should just be a fixed value.
        targetValue = 0
        hiTargetLeft, hiTargetRight = targetValue,targetValue
        hiOffsetLeft, hiOffsetRight = 0, 0


    end


    if highbeam > 0 then

        currentValueHighLeft = takeStep(hiTargetLeft + hiOffsetLeft, leftHigh, dt, currentValueHighLeft, -15+hiOffsetDirectional, 15+hiOffsetDirectional, hiSmoothL, overrideLeft)
        currentValueHighRight = takeStep(hiTargetRight - hiOffsetRight, rightHigh, dt, currentValueHighRight, -15-hiOffsetDirectional, 15-hiOffsetDirectional, hiSmoothR, overrideRight)
        
        -- suboptimal, wastes resources.
        if leftOff > 0 then
            electrics.values[leftHigh] = 0
        end
        
        if rightOff > 0 then
            electrics.values[rightHigh] = 0
        end
    end

    -- Dumb fix
    offset = (highbeam*12.5)
    currentValueLeft = takeStep(targetValue + offset, left, dt, currentValueLeft, -20 + (offset * 2), 20, 8, -1)
    currentValueRight = takeStep(targetValue - offset, right, dt, currentValueRight, -20, 20 - (offset * 2), 8, -1)

else 

    -- Keep the lights "ready" by assigning them the targetvalue
    reset()
    currentValueLeft = targetValue
    currentValueRight = targetValue
end