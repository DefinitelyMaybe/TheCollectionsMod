--TheModScript
include("Scripts/Core/Common.lua")

-------------------------------------------------------------------------------
if TheModScript == nil then
	TheModScript = EternusEngine.ModScriptClass.Subclass("TheModScript")
end

-------------------------------------------------------------------------------
function TheModScript:Constructor()
end

 -------------------------------------------------------------------------------
 -- Called once from C++ at engine initialization time
function TheModScript:Initialize()
	Eternus.CraftingSystem:ParseRecipeFile("Data/Crafting/Decor_Recipes.txt")
	Eternus.CraftingSystem:ParseRecipeFile("Data/Crafting/Tools_Recipes.txt")
	Eternus.CraftingSystem:ParseRecipeFile("Data/Crafting/Weapon_Recipes.txt")
	Eternus.CraftingSystem:ParseRecipeFile("Data/Crafting/Repair_Recipes.txt")
end

-------------------------------------------------------------------------------
-- Called from C++ when the current game enters 
function TheModScript:Enter()
end

-------------------------------------------------------------------------------
-- Called from C++ when the game leaves it current mode
function TheModScript:Leave()
end

-------------------------------------------------------------------------------
-- Called from C++ every update tick
function TheModScript:Process(dt)
end

-------------------------------------------------------------------------------
EntityFramework:RegisterModScript(TheModScript)