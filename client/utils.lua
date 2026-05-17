
Utils = {}

function Utils.EnsureRopeTexturesLoaded()
	if not RopeAreTexturesLoaded() then
		RopeLoadTextures()
		while not RopeAreTexturesLoaded() do
			Wait(0)
		end
	end
end

function Utils.CleanupRopeTexturesIfUnused()
	local ropes = GetAllRopes()
	if type(ropes) == "table" and #ropes == 0 then
		RopeUnloadTextures()
	end
end
