------------------------ Scene setup ------------------------
local composer = require( "composer" )
local perspective = require( "perspective" )
local physics = require( "physics" )

local scene = composer.newScene()

------------------------ Initialize variables ------------------------
local settings
local camera

local player
local ammoDisplay = {}

local map
local environment = {}

local sceneGroup
local backGroup
local mainGroup
local uiGroup

------------------------ Utility functions ------------------------

-- Convert degrees to radians
function toDeg( rad )
 return rad * 57.2958
end

------------------------ Game Functions ------------------------

-- Fires guns that don't have projectiles
function shootNonProjectile( shotAngle )
  --Initialize the shot
  local layer = camera:layer( 1 )
  local shot = display.newPolygon( mainGroup, player.x + layer.x, player.y + layer.y, settings.guns[player.gun].hitbox )
  shot:setFillColor( 1, 0, 0 )
  shot.rotation = toDeg( shotAngle )
  shot.anchorX = 0

  player.rotation = toDeg( shotAngle ) -- Set player rotation

  -- Remove the shot
  timer.performWithDelay( settings.guns[player.gun].activeTime, function()
    shot:removeSelf()
    shot = nil
  end )
end

------------------------ Event Functions ------------------------

-- Function that handles shooting
function shoot( event )
  print("fired a shot")
  if( player.readyToFire == true ) then -- Only shoot if the player is able to
    -- Calculate shot angle
    local layer = camera:layer(1)
    local xDiff = event.x - ( player.x + layer.x )
    local yDiff = event.y - ( player.y + layer.y )
    local angle = math.atan2( yDiff, xDiff )

    if ( settings.guns[player.gun].projectile ) then
      -- Projectile weapons
    else
      -- Non-projectile weapons
      shootNonProjectile( angle )
    end

    -- Move player
    local xForce = math.cos( angle ) * settings.guns[player.gun].recoil * -1
    local yForce = math.sin( angle ) * settings.guns[player.gun].recoil * -1
    player:applyLinearImpulse( xForce, yForce, player.x, player.y )

    --
    player.readyToFire = false
    if(player.ammo > 1)then
       player.ammo = player.ammo - 1
       timer.performWithDelay( settings.guns[player.gun].attackSpeed, function()
         player.readyToFire = true
       end )
    else -- reloading
        print( "reloading ... " )
        timer.performWithDelay( settings.guns[player.gun].reloadTime, function()
         player.ammo = settings.guns[player.gun].magazine
         player.readyToFire = true
         print( "reloaded!" )
       end )
    end
  end
end

------------------------ Scene Functions ------------------------

-- create()
function scene:create( event )
  -- Initialise settings
  settings = {
    player = {
      size = 125,
      defaultGun = "shotgun",
      friction = 3
    },

    guns = {
      shotgun = {
        projectile = false,
        recoil = 5, -- distance the character travels on attack
        magazine = 6,
        reloadTime = 2000, -- miliseconds
        attackSpeed = 500, -- minimum time between shots
        hitbox = {0,0, 500,-300, 500,300},
        activeTime = 200,
        ammoIcon = 
      }
    }
  }

  -- Scene Setup
	sceneGroup = self.view

  -- Physics engine setup
  physics.start()
  physics.setGravity( 0, 0 )
  physics.setDrawMode( "hybrid" )  -- Overlays collision outlines on normal display objects for debug purposes
  physics.pause()  -- Temporarily pause the physics engine while scene loads

	-- Set up display groups
	backGroup = display.newGroup()
	sceneGroup:insert( backGroup )

	mainGroup = display.newGroup()
	sceneGroup:insert( mainGroup )

	uiGroup = display.newGroup()
	sceneGroup:insert( uiGroup )

  -- Setup the camera
  camera = perspective.createView()

  --Initialize the map
  map = display.newRect( backGroup, 0, 0, 1080, 1920)
  map.anchorX = 0
  map.anchorY = 0
  map:setFillColor( 0.2, 0.2, 0.2 )

  -- Initialize environment
  -- Temporary Border
  environment.topWall = display.newRect( mainGroup, 0, 0, 2500, 100 )
  environment.leftWall = display.newRect( mainGroup, 25, display.contentCenterY, 100, 1920 )
  environment.rightWall = display.newRect( mainGroup, 1055, display.contentCenterY, 100, 1920 )
  environment.bottomWall = display.newRect( mainGroup, 0, 1920, 2500, 100 )

  physics.addBody( environment.topWall, "static", {bounce = 0} )
  physics.addBody( environment.leftWall, "static", {bounce = 0}  )
  physics.addBody( environment.rightWall, "static", {bounce = 0}  )
  physics.addBody( environment.bottomWall, "static", {bounce = 0}  )

  camera:add( environment.topWall, 2 )
  camera:add( environment.leftWall, 2 )
  camera:add( environment.rightWall, 2 )
  camera:add( environment.bottomWall, 2 )

  -- Initialize the player
  player = display.newRect( mainGroup, display.contentCenterX, display.contentCenterY,
    settings.player.size, settings.player.size )
  player.gun = settings.player.defaultGun
  player.readyToFire = true
  player.ammo = settings.guns[player.gun].magazine

  physics.addBody( player, "dynamic", {friction = settings.player.friction, bounce = 0} )
  player.linearDamping = settings.player.friction
  player.angularDamping = settings.player.friction

  camera:add ( player, 1 ) -- Add player to layer 1 of the camera

  -- Start the camera
  camera.damping = 10
  camera:setFocus( player )
  camera:track()

  --Initialize event listeners
  sceneGroup:addEventListener( "tap", shoot )
end


-- Runs when scene is fully loaded
function scene:show( event )
  if ( event.phase == "did" ) then
    physics.start()
	end
end


-- Runs when scene is off screen
function scene:hide( event )
	if ( event.phase == "did" ) then
		-- Stop physics and remove the scene
    physics.pause()
		composer.removeScene( "game" )
	end
end

------------------------ Scene event function listeners ------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )

return scene
