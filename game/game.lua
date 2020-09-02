------------------------ Scene setup ------------------------
local composer = require( "composer" )
local perspective = require( "perspective" )
local physics = require( "physics" )

local scene = composer.newScene()

------------------------ Initialize variables ------------------------
local settings
local camera
local pseudoQuadrant = {} -- need quadrants based on the origin being the player
local shotQuadrant

local player
local ammoDisplay = {}

local map
local environment = {}
local enemies = {}

------------------------ Utility functions ------------------------

-- Convert radians to degrees
function toDeg( rad )
 return rad * 57.2958
end

------------------------ Game Functions ------------------------

-- Fires guns that don't have projectiles
function shootNonProjectile( shotAngle ) -- ended up specific to the shotgun, each gun will probably have its own function
  --Load the pellets
  local pellets = {}
  local testLine = {}

  for i = 1, settings.guns[player.gun].pelletCount, 1 do
    pellets[i] = physics.rayCast( player.x, player.y, (math.cos( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.x,
                                (math.sin( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.y, "closest" )
    if ( pellets[i] ) then -- if they hit a display object
      testLine[i] = display.newLine( player.x, player.y, pellets[i][1].position.x, pellets[i][1].position.y )
      print( "Pellet " .. i .. " Hit ", pellets[i][1].object.type )
      onBulletCollision( pellets[i][1].object, settings.guns[player.gun] )
    else -- if they miss
      testLine[i] = display.newLine( player.x, player.y, (math.cos( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.x,
                                   (math.sin( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.y )
      print( "miss" )
    end
    testLine[i]:setStrokeColor( 20, 19, 0 ) -- why the fuck is this yellow??
    camera:add( testLine[i], 2 )
  end

  -- Remove the shot
  timer.performWithDelay( settings.guns[player.gun].activeTime, function()
    for i = 1, #testLine, 1 do
      testLine[i]:removeSelf()
      testLine[i] = nil
    end
  end )
--[[  local shot = display.newPolygon( player.x, player.y, settings.guns[player.gun].shape )
  shot:setFillColor( 1, 0, 0 )
  shot.rotation = toDeg( shotAngle )
  shot.anchorX = 0
  camera:add(shot, 1)

  physics.addBody( shot, "dynamic", { shape = settings.guns[player.gun].hitbox } )
  shot.isSensor = true
  shot.collision = onBulletCollision
  shot:addEventListener( "collision" )

  player.rotation = toDeg( shotAngle ) -- Set player rotation

  -- Remove the shot
  timer.performWithDelay( settings.guns[player.gun].activeTime, function()
    shot:removeSelf()
    shot = nil
  end )]]
end

 -- Spawns enemy in game
function spawnEnemy()
  local spawnLocation = environment.enemySpawns[ math.random( #environment.enemySpawns ) ]
  local enemy = display.newRect( spawnLocation.x, spawnLocation.y, settings.enemies.enemyName.size, settings.enemies.enemyName.size )
  enemy.type = "enemy"
  enemy.slot = #enemies + 1
  enemy.HP = settings.enemies.enemyName.maxHP

  camera:add( enemy, 1 )

  physics.addBody( enemy, "dynamic", {bounce = 0} )
  enemy.linearDamping = settings.player.friction
  enemy.angularDamping = settings.player.friction

  table.insert( enemies, enemy )
end

------------------------ Event Functions ------------------------

-- Function that handles shooting
function shoot( event )
  if( player.readyToFire == true ) then -- Only shoot if the player is able to
    -- Calculate shot angle
    local layer = camera:layer(1)
    local xDiff = event.x - ( player.x + layer.x )
    local yDiff = event.y - ( player.y + layer.y )
    local angle = math.atan2( yDiff, xDiff )
    print(toDeg(angle)) -- q1 is -90 to 0
                        -- q2 is 0 to 90
                        -- q3 is 90 to 180
                        -- q4 is -180 to -90

    -- Move player
    local xForce = math.cos( angle ) * settings.guns[player.gun].recoil * -1
    local yForce = math.sin( angle ) * settings.guns[player.gun].recoil * -1
    player:applyLinearImpulse( xForce, yForce, player.x, player.y )
    player.rotation = angle -- Set player rotation in rads

    if ( settings.guns[player.gun].projectile ) then
      -- Projectile weapons
    else
      -- Non-projectile weapons
      shootNonProjectile( angle )
    end


    -- Disable shooting
    player.readyToFire = false
    if ( player.ammo > 1 ) then
       ammoDisplay[player.ammo].isVisible = false
       player.ammo = player.ammo - 1
       timer.performWithDelay( settings.guns[player.gun].attackSpeed, function()
         player.readyToFire = true
       end )
    else -- reloading
        ammoDisplay[player.ammo].isVisible = false
        timer.performWithDelay( settings.guns[player.gun].reloadTime, function()
         player.ammo = settings.guns[player.gun].magazine
         player.readyToFire = true
         for i = 1, player.ammo, 1 do
            ammoDisplay[i].isVisible = true
         end
       end )
    end
  end
end

-- Handle bullet collision
function onBulletCollision( victim, source ) -- thing getting hit, and the thing hitting it
  if ( victim.type == "enemy" ) then
    local xForce = math.cos( player.rotation ) * source.knockback --* -1
    local yForce = math.sin( player.rotation ) * source.knockback --* -1
    victim:applyLinearImpulse( xForce, yForce, victim.x, victim.y )

    victim.HP = victim.HP - source.damage
    print(victim.type .. " took " .. source.damage .. " damage from " .. source.name)
    if (victim.HP <= 0) then -- enemy death
      victim:removeSelf()
      table.remove( enemies, victim.slot )
    end
  end
end

------------------------ Scene Functions ------------------------

-- create()
function scene:create( event )
  -- Load settings
  settings = {
    game = {
      spawnTime = 5000
    },

    player = {
      size = 125,
      defaultGun = "shotgun",
      friction = 3
    },

    enemies = {
      enemyName = {
        size = 125,
        maxHP = 20
      }
    },

    guns = {
      shotgun = {
        name = "shotgun",
        projectile = false,
        recoil = 5, -- distance the character travels on attack
        damage = 5, -- damage per pellet
        knockback = 1, -- distance enemy moves back when hit
        magazine = 6,
        reloadTime = 2000, -- miliseconds
        attackSpeed = 500, -- minimum time between shots
        range = 400, -- Hypotneus value of the shot angle
        pelletCount = 5, -- number of pellets per shot
        spread = { -1/3, -1/6, 0, 1/6, 1/3 }, -- spread of the pellets
        shape = {0,0, 500,-300, 500,300},
        hitbox = {-250,0, 250,-300, 250,300},
        activeTime = 200,
        ammoIcon = "Assets/Pixel/weaponAssets/shotgunAmmo.png",
        ammoIconSize = {width = 50, height = 132}, -- vertical image, 2.65 ratio
        ammoIconSpacing = 70
      }
    },

    ui = {
      ammoCount = {
        startPos = {x = 120, y = 1800}
      }
    }
  }

  -- Physics engine setup
  physics.start()
  physics.setGravity( 0, 0 )
  physics.setDrawMode( "hybrid" )  -- Overlays collision outlines on normal display objects for debug purposes
  physics.pause()  -- Temporarily pause the physics engine while scene loads

  -- Setup the camera
  camera = perspective.createView()

  --Load the map
  map = display.newRect( 0, 0, 1080, 1920 )
  map.anchorX = 0
  map.anchorY = 0
  map:setFillColor( 0.2, 0.2, 0.2 )
  camera:add( map, 2 )

  -- Load environment
  -- Temporary Border
  environment.topWall = display.newRect( 0, 0, 2500, 100 )
  environment.leftWall = display.newRect( 25, display.contentCenterY, 100, 1920 )
  environment.rightWall = display.newRect( 1055, display.contentCenterY, 100, 1920 )
  environment.bottomWall = display.newRect( 0, 1920, 2500, 100 )

  environment.topWall.type = "wall"
  environment.leftWall.type = "wall"
  environment.rightWall.type = "wall"
  environment.bottomWall.type = "wall"

  physics.addBody( environment.topWall, "static", {bounce = 0} )
  physics.addBody( environment.leftWall, "static", {bounce = 0}  )
  physics.addBody( environment.rightWall, "static", {bounce = 0}  )
  physics.addBody( environment.bottomWall, "static", {bounce = 0}  )

  camera:add( environment.topWall, 2 )
  camera:add( environment.leftWall, 2 )
  camera:add( environment.rightWall, 2 )
  camera:add( environment.bottomWall, 2 )

  -- Load enemy spawns
  environment.enemySpawns = {
    { x = 600, y = 200 },
    { x = 400, y = 400 },
    { x = 800, y = 1500 }
  }

  -- Load the player
  player = display.newRect( display.contentCenterX, display.contentCenterY,
    settings.player.size, settings.player.size )
  player.gun = settings.player.defaultGun
  player.readyToFire = true
  player.ammo = settings.guns[player.gun].magazine

  physics.addBody( player, "dynamic", {bounce = 0} )
  player.linearDamping = settings.player.friction
  player.angularDamping = settings.player.friction

  camera:add ( player, 1 ) -- Add player to layer 2 of the camera

  -- Start the camera
  camera.damping = 10
  camera:setFocus( player )
  camera:track()

  -- Load the ammo count
  for i = 1, player.ammo, 1 do
    ammoDisplay[i] = display.newImageRect( settings.guns[player.gun].ammoIcon, settings.guns[player.gun].ammoIconSize.width, settings.guns[player.gun].ammoIconSize.height )
    ammoDisplay[i].x = settings.ui.ammoCount.startPos.x + ( settings.guns[player.gun].ammoIconSpacing * ( i - 1 ))
    ammoDisplay[i].y = settings.ui.ammoCount.startPos.y
  end

  --Initialize event listeners
  Runtime:addEventListener( "tap", shoot )
end


-- Runs when scene is fully loaded
function scene:show( event )
  if ( event.phase == "did" ) then
    physics.start()
    -- START SPAWNING ENEMIES CHANGE THIS NOT FUTURE PROOF
    timer.performWithDelay( settings.game.spawnTime, spawnEnemy, -1 )
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
