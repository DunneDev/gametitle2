
local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

-- Physics engine setup
local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )
physics.setDrawMode( "hybrid" )  -- Overlays collision outlines on normal display objects

-- Initialize variables
local settings

local player
local bullets = {}
local map

local backGroup
local mainGroup
local uiGroup

-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------i------------------------------------------
--Utility functions

-- Convert degrees to radians
function toDeg( rad )
 return rad * 57.2958
end


-- Fires guns that don't have projectiles
function shootNonProjectile( shotAngle )
  local shot = display.newPolygon( mainGroup, player.x, player.y, settings.guns[player.gun].hitbox )
  shot:setFillColor(1,0,0)
  shot.rotation = toDeg( shotAngle )
  shot.anchorX = 0

  timer.performWithDelay( settings.guns[player.gun].activeTime, function()
    shot:removeSelf()
    shot = nil
  end)
end

-- Function that runs every time screen is tapped
function onTap( event )
  local xDiff = event.x - player.x
  local yDiff = event.y - player.y

  local angle = math.atan2( yDiff, xDiff )
  if (settings.guns[player.gun].projectile) then

  else
    shootNonProjectile( angle )
  end

  -- Move player
  local xForce = math.cos(angle) * settings.guns[player.gun].recoil * -1
  local yForce = math.sin(angle) * settings.guns[player.gun].recoil * -1
  player:applyLinearImpulse( xForce, yForce, player.x, player.y )
end

-- create()
function scene:create( event )
  settings = {
    player = {
      size = 125,
      defaultGun = "shotgun",
      friction = 1
    },
    guns = {
      shotgun = {
        projectile = false,
        recoil = 0.3, -- placeholder
        magazine = 6,
        reloadTime = 1000, -- miliseconds
        attackSpeed = 400, -- minimum time between shots
        hitbox = {0,0, 500,-300, 500,300},
        activeTime = 200
      }
    }
  }

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

  physics.pause()  -- Temporarily pause the physics engine

	-- Set up display groups
	backGroup = display.newGroup()
	sceneGroup:insert( backGroup )

	mainGroup = display.newGroup()
	sceneGroup:insert( mainGroup )

	uiGroup = display.newGroup()
	sceneGroup:insert( uiGroup )

  --Initialize the mainGroup
  map = display.newRect( backGroup, 0, 0, 1080, 1920)
  map.anchorX = 0
  map.anchorY = 0
  map:setFillColor( 0.2, 0.2, 0.2 )

  -- Initialize the player
  player = display.newRect( mainGroup, display.contentCenterX, display.contentCenterY,
    settings.player.size, settings.player.size )
  player.gun = settings.player.defaultGun

  physics.addBody( player, "dynamic", {friction = 1} )

  --Initialize event listeners
  sceneGroup:addEventListener( "tap", onTap )
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
    physics.start()
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
    physics.pause()
		composer.removeScene( "game" )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
