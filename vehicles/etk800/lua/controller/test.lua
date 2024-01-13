-- Authored by NickRyge

-- This module includes helper-functions to allow for total control over a jbeam prop.
-- The original dev implementation only moves a prop along a single rotational axis. 
-- - That is great for rotating driveshafts and police lights, but it doesn't really provide
-- any movement control. 

-- This module solves that problem.
-- The basic idea is to hijack the propUpdate function and instead do all the updating from here.

-- Prop list from the vehicle data.
-- This cannot populate itself for some reason in the vehicle lua, so this must be done somehow else
-- TODO: Create factory method as a replacement for a constructor that demands a prop table.
local props = {}

-- Stored hijackedProps
local hijackedProps = {}

-- Hacky solution.
function SetPropsList(propsList)
    props = propsList
end

function Test(inputText)
    print(inputText)
end

-- Returns list of hijacked props
function GetHijackedProps()
    return hijackedProps
end

-- Hijacks a single prop.
-- Would like 
function HijackSingleProp(propFunction, name)
    for _, v in pairs(props) do
        if v.func == propFunction then
            hijackedProps[name] = v
            hijackedProps[name].id = hijackedProps[name].pid
            hijackedProps[name].pid = nil
        end
    end

    print("Hijacked " .. hijackedProps[name].func)
    return hijackedProps[name]
end

-- Always leave the multiplier at 1 for best results. It's far easier to manage that way as it is possible to manage rotation (and movement) entirely
-- by just converting degrees to radians, as that's what the rotation multipliers use. So math.rad(180) for rotXMult will turn the prop 180 degrees around x.
function UpdateProp(propId, posXMult, posYMult, posZMult, rotXMult, rotYMult, rotZMult, isHidden, value, mulitplier)
    obj:propUpdate(props[propId].id, posXMult, posYMult, posZMult, rotXMult, rotYMult, rotZMult, isHidden, value, mulitplier)
end
