include("Scripts/Interactable.lua")
include("Scripts/Objects/PlaceableObject.lua")

-------------------------------------------------------------------------------
-- Object with a state machine defining four states, Closed and Open are idle
-- states where the object doesn't update, and Opening and Closing are
-- transition states between the first two.
DoorFrame = PlaceableObject.Subclass("DoorFrame")

-- Enumerations
DoorFrame.EDoorState = 
{
	Closed 	= 0,
	Opening = 1,
	Open   	= 2,
	Closing = 3
}

-- Static variables
DoorFrame.TimeToOpen  = 1.0	-- How long door takes to transition between Open/Closed.
DoorFrame.AngleToOpen = 0.0	-- How wide to swing when opening/closing.
DoorFrame.ReverseOpeningDirection 	  = false	-- Flips the direction the door opens.  Necessary incase model has hinge on the other side.

-------------------------------------------------------------------------------
function DoorFrame:Constructor(args)
	if (args.timeToOpen) then
		self.TimeToOpen = args.timeToOpen
	end
	
	if (args.angleToOpen) then
		self.AngleToOpen = args.angleToOpen
	end
	
	-- For some reason our parsing puts single strings in a numbered key as the value.
	-- This means that checking for them is a pain.  Really, they should be getting
	-- set into a key with a value of true, 1, or some other constant value, so checking
	-- for them is as simple as checking to see if the key exists rather than having
	-- to iterate the entire table looking for a specific value.
	if (args.reverseOpeningDirection) then
		self.ReverseOpeningDirection = true
	end
	
	self.m_doorPart = nil
	
	self.m_doorState = DoorFrame.EDoorState.Closed
	
	-- These are set during interaction and only used during the update tick.
	self.m_lastAngle = 0.0
	self.m_doorTimer = 0.0
	self.m_rotationAxis = vec3.new(0.0, 1.0, 0.0)
	
	if (args.parentAttachPoint) then
		self.m_parentAttach = args.parentAttachPoint
	else
		self.m_parentAttach = ""
	end
	
	if (args.childAttachPoint) then
		self.m_childAttach = args.childAttachPoint
	else
		self.m_childAttach = ""
	end
	
	if (args.doorObject) then
		self.m_doorObject = args.doorObject
	else
		self.m_doorObject = ""
	end
	
end

-------------------------------------------------------------------------------
function DoorFrame:PostLoad()
	DoorFrame.__super.PostLoad(self)
	-- Attach if necessary.
	local children = self:NKGetChildren()
	for key, value in pairs(children) do
		local childInst = value:NKGetInstance()
		
		if (childInst) then
			if (childInst:InstanceOf(PlaceableObject) and childInst:NKGetName() == self.m_doorObject) then
				self.m_doorPart = childInst
				self.m_doorPart:RefreshPhysics()
				NKWarn("Found door object")
			end
		end
	end
		
	if (not self.m_doorPart) then
		if (self.m_doorObject ~= "" and self.m_parentAttach ~= "" and self.m_childAttach ~= "") then
			self.m_doorPart = Eternus.GameObjectSystem:NKCreateGameObject(self.m_doorObject, true):NKGetInstance()
			self:NKAddChildObject(self.m_doorPart)
			self:NKAddChildAtAttachPoint(self.m_doorPart.object, self.m_childAttach, self.m_parentAttach, true)
			NKWarn("Created door object")
		end
	end
end


-------------------------------------------------------------------------------
-- DoorFrame normally only updates while in Opening and Closing states.
function DoorFrame:Update(dt) 
	if (self.m_doorState == DoorFrame.EDoorState.Open or self.m_doorState == DoorFrame.EDoorState.Closed) then
		return
	end
	
	self.m_doorTimer = self.m_doorTimer + dt
	local currentState = self.m_doorState
	local progress = self.m_doorTimer / self.TimeToOpen
	if (progress > 1.0) then
		progress = 1.0
	end
	
	local newOrientation = self:CalculateOrientation(progress)
	self.m_doorPart:NKSetOrientation(newOrientation, true, false)
	self.m_doorPart:RefreshPhysics()
	
	if (progress >= 1.0) then
		self:FinishRotating()
	end

end

-------------------------------------------------------------------------------
-- Called when the final rotation angle has been reached. Advances the state machine.
function DoorFrame:FinishRotating()
	self:NKEnableScriptProcessing(false)
	if (self.m_doorState == DoorFrame.EDoorState.Opening) then
		self.m_doorState = DoorFrame.EDoorState.Open
	elseif (self.m_doorState == DoorFrame.EDoorState.Closing) then
		self.m_doorState = DoorFrame.EDoorState.Closed
	end
end

-------------------------------------------------------------------------------
-- Given a progress into the current state, determines the correct orientation
-- for the door.
function DoorFrame:CalculateOrientation( progress )
	if (self.m_doorState == DoorFrame.EDoorState.Open or self.m_doorState == DoorFrame.EDoorState.Closed) then
		return self:NKGetOrientation()
	end
	
	local currentAngle = 0.0
	if (self.m_doorState == DoorFrame.EDoorState.Opening) then
		currentAngle = progress * self.AngleToOpen
		
		if (self.ReverseOpeningDirection) then
			currentAngle = -currentAngle
		end
	elseif (self.m_doorState == DoorFrame.EDoorState.Closing) then
		currentAngle = (1-progress) * self.m_lastAngle
	end
	
	local newOrientation = quat.new(1.0, 0.0, 0.0, 0.0)
	GLM.Rotate(newOrientation, currentAngle, self.m_rotationAxis)
	return newOrientation
end

-------------------------------------------------------------------------------
-- Interact with the door to open/close it.  Interactions are ignored if door
-- is not in Open or Closed state.
function DoorFrame:Interact( args )
	if (self.m_doorState == DoorFrame.EDoorState.Closed) then
		-- Modify angle to account for any needed corrections.
		local angle = self.AngleToOpen
		
		if (self.ReverseOpeningDirection) then
			angle = -angle
		end
		
		self.m_lastAngle = angle
		
		-- Set the door state.
		self.m_doorState = DoorFrame.EDoorState.Opening
		self.m_doorTimer = 0.0
		self:NKEnableScriptProcessing(true)
		
		return true
	elseif (self.m_doorState == DoorFrame.EDoorState.Open) then
		-- Set the door state.
		self.m_doorState = DoorFrame.EDoorState.Closing
		self.m_doorTimer = 0.0
		self:NKEnableScriptProcessing(true)
		
		return true
	end
	
	-- Failed (door was already opening/closing)
	return false
end

-------------------------------------------------------------------------------
-- If door is picked up, rotation is ended prematurely and the door is reset
-- to the Closed state.
function DoorFrame:PickedUp()
	self:FinishRotating()
	self.m_doorState = DoorFrame.EDoorState.Closed
	self.m_doorPart:NKSetOrientation(quat.new(1.0, 0.0, 0.0, 0.0), true, false)
end

-------------------------------------------------------------------------------
function DoorFrame:NetSerializeConstruction( stream )
	self:NetSerialize(stream)
	local orientation = self.m_doorPart:NKGetOrientation()
	stream:NKWriteDouble(orientation:w())
	stream:NKWriteDouble(orientation:x())
	stream:NKWriteDouble(orientation:y())
	stream:NKWriteDouble(orientation:z())
end

-------------------------------------------------------------------------------
function DoorFrame:NetDeserializeConstruction( stream )
	NKWarn("NetDeserializeConstruction")
	self:NetDeserialize(stream)
	
	local orientation = quat(stream:NKReadDouble(),stream:NKReadDouble(),stream:NKReadDouble(),stream:NKReadDouble())
	
	self.m_doorPart:NKSetOrientation(orientation, true, false)
	self.m_doorPart:RefreshPhysics()
end

-------------------------------------------------------------------------------
function DoorFrame:NetSerialize( stream, conn )
	stream:NKWriteInt(self.m_doorState)
	stream:NKWriteDouble(self.m_doorTimer)
	stream:NKWriteDouble(self.m_lastAngle)
end

-------------------------------------------------------------------------------
function DoorFrame:NetDeserialize( stream )
	local doorState = stream:NKReadInt()
	local doorTimer = stream:NKReadDouble()
	local lastAngle = stream:NKReadDouble()
	
	if (self.m_doorState ~= doorState) then
		self.m_doorState = doorState
		self.m_doorTimer = doorTimer
		self.m_lastAngle = lastAngle
		
		if (self.m_doorState == DoorFrame.EDoorState.Closing or self.m_doorState == DoorFrame.EDoorState.Opening) then
			self:NKEnableScriptProcessing(true)
		elseif (self.m_doorState == DoorFrame.EDoorState.Closed) then
			self.m_doorPart:NKSetOrientation(orientation, true, false)
			self.m_doorPart:RefreshPhysics()
		end
	end
end


----------------
-- Save logic --
----------------

-------------------------------------------------------------------------------
function DoorFrame:Save(outData)
	outData.doorData = {}
	outData.doorData.timeToOpen = self.TimeToOpen
	outData.doorData.angleToOpen = self.AngleToOpen
	outData.doorData.reverseOpeningDirection = self.ReverseOpeningDirection
	
	if (self.m_doorState == DoorFrame.EDoorState.Opening) then
		outData.doorData.doorState = DoorFrame.EDoorState.Open
	elseif (self.m_doorState == DoorFrame.EDoorState.Closing) then
		outData.doorData.doorState = DoorFrame.EDoorState.Closed
	else
		outData.doorData.doorState = self.m_doorState
	end
	
	outData.doorData.lastAngle = self.m_lastAngle
end

-------------------------------------------------------------------------------
function DoorFrame:Restore(inData, version)
	if (inData.doorData ~= nil) then
		self.TimeToOpen = inData.doorData.timeToOpen
		self.AngleToOpen = inData.doorData.angleToOpen
		self.ReverseOpeningDirection = inData.doorData.reverseOpeningDirection
		self.m_doorState = inData.doorData.doorState
		self.m_lastAngle = inData.doorData.lastAngle
		self.m_doorTimer = 0.0 -- We save as either closed or open, so just reset the timer.
		
		self.m_restored = true
	else
		NKPrint("Trying to restore door, but it hasn't saved any doorData!")
		return
	end
end



-------------------------------------------------------------------------------
EntityFramework:RegisterGameObject(DoorFrame)