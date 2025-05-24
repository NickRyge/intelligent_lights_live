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


---Setter for the prop list 
---@param propsList any
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


---Hijacks a prop from the prop-table, and prevents the game from updating the prop automatically, while leaving the prop 
---available to update manually.
---@param propFunction string The function string, e.i "LeftHeadlight" - The electrics function name.
---@param name string needs to be the name 
---@return prop 
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
---comment
---@param propId number The ID of the prop-object, to find it in the proptable.
---@param posXMult number Position X-axis multiplier
---@param posYMult number Position Y-axis multiplier
---@param posZMult number Position Z-axis multiplier
---@param rotXMult number Rotational X-axis multiplier
---@param rotYMult number Rotational Y-axis multiplier
---@param rotZMult number Rotational Z-axis multiplier
---@param isHidden boolean Whether the prop is hidden
---@param value number Value of the prop - must be positive number bigger than 0 to turn on lights. Irrelevant for object props
---@param mulitplier number Global multiplier
function UpdateProp(propId, posXMult, posYMult, posZMult, rotXMult, rotYMult, rotZMult, isHidden, value, mulitplier)
    obj:propUpdate(props[propId].id, posXMult, posYMult, posZMult, rotXMult, rotYMult, rotZMult, isHidden, value, mulitplier)
end
