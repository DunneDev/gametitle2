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
local enemies = {}
local traps = {}
local surfaces = {}
local stationaryWeapons = {}

local gameLoopCounter = 0
local numberOfEnemies = 0
local enemyGenerator

------------------------ Utility functions ------------------------

-- Convert radians to degrees
function toDeg( rad )
 return rad * 57.2958
end

function toRad( deg )
  return deg / 57.2958
end

------------------------- Game Functions ------------------------

-- when anything takes damage
function damage( victim, damage )
  if ( victim.type == "enemy" )then -- enemy takes damage
    victim.HP = victim.HP - damage

    if ( victim.HP <= 0 )then -- enemy death
      victim.status = "dead"
      victim:removeSelf()
      enemies[victim.slot] = nil
      print("enemy " .. victim.ID .. " died") -- i guess this still works because the garbage collector hasnt scrapped the table yet?
    end

  elseif ( victim.type == "player" )then -- player takes damage
    victim.HP = victim.HP - damage

    if ( victim.HP <= 0 )then -- player death
      print("player died")
      -- "freeze" the game (except idle animations)
        --timer.performWithDelay( 500, function() player:setLinearVelocity(0,0) end)
      player:setLinearVelocity(0,0)
      for i = 1, #enemies, 1 do -- freeze all the enemies
        if( enemies[i] )then
          enemies[i]:setLinearVelocity(0,0)
        end
      end
      timer.cancel( enemyGenerator ) -- stop spawning enemies
      --Runtime:removeEventListener( "enterFrame", gameLoop ) -- stop the gameLoop
      -- disable player input
      Runtime:removeEventListener( "tap", shoot )
      --player.readyToFire = false -- bug: removing the gameLoop listener above makes this line stop working
                                   -- not fixed but technicaly doesnt matter cause removing the tap listener is even better
      -- send to an end of run scene after a few seconds

    end
  end
end

-- currently not needed but could be used later
-- Initialize game loop
function gameLoop( event ) -- checks for certain events every frame
                           -- event.time = time passed in miliseconds
  gameLoopCounter = gameLoopCounter + 1
  if ( gameLoopCounter % 15 == 0 )then -- runs the code every x frames instead of 60

  end
  --return true
end
-- Fires guns with projectiles
function shootProjectile( shotAngle, weapon, user )

  if ( weapon.table.automatic == false )then -- start/stop firing per tap

  else -- fire once per tap
    local projectile = display.newCircle( weapon.x + math.cos(shotAngle) * (weapon.path.radius), weapon.y + math.sin(shotAngle) * (weapon.path.radius), weapon.table.bulletSize )
    physics.addBody( projectile, "dynamic", { radius = weapon.table.bulletSize, filter = {groupIndex = -1} } )
    projectile.damage = weapon.table.damage
    projectile.gravityScale = 0
    projectile.isBullet = true
    projectile.collision = projectileCollisionHandler
    camera:add( projectile, 2 )

    local xForce = math.cos( shotAngle ) * weapon.table.bulletSpeed
    local yForce = math.sin( shotAngle ) * weapon.table.bulletSpeed

    projectile:addEventListener("collision")
    projectile:applyLinearImpulse( xForce, yForce, projectile.x, projectile.y )
  end

end

-- Handles projectile collisions
function projectileCollisionHandler(self, event)
  local projectile = self
  local victim = event.other

  if ( victim.type == "enemy" )then
    print( "hit enemy " .. victim.ID )
    damage( victim, projectile.damage )

  elseif ( victim.type == "player" )then
    print( "hit player" )
    damage( victim, projectile.damage )
  elseif ( victim.type == "wall" )then
    -- play animation
  end

  self:removeSelf()
end
-- Fires guns that don't have projectiles
function shootNonProjectile( shotAngle ) -- ended up specific to the shotgun, each gun will probably have its own function
  --Load the pellets
  local pellets = {}
  local testLine = {}

  audio.play( settings.guns[player.gun].audio.shotgunBlast, { duration = 430 }) -- static placeholder value
    if (player.ammo > 1) then
      timer.performWithDelay( 430, function()
        audio.play( settings.guns[player.gun].audio.shotgunPump )
      end)
    else
      timer.performWithDelay( 430, function()
        audio.play( settings.guns[player.gun].audio.shotgunReload, { duration = settings.guns[player.gun].reloadTime })
      end)
    end


  for i = 1, settings.guns[player.gun].pelletCount, 1 do
    pellets[i] = physics.rayCast( player.x, player.y, (math.cos( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.x,
                                (math.sin( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.y, "closest" )
    if ( pellets[i] ) then -- if they hit a display object
      testLine[i] = display.newLine( player.x, player.y, pellets[i][1].position.x, pellets[i][1].position.y )
      --print( "Pellet " .. i .. " Hit ", pellets[i][1].object.type )
      onBulletCollision( pellets[i][1].object, settings.guns[player.gun] )
    else -- if they miss
      testLine[i] = display.newLine( player.x, player.y, (math.cos( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.x,
                                   (math.sin( shotAngle + settings.guns[player.gun].spread[i] ) * settings.guns[player.gun].range) + player.y )
      --print( "miss" )
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
  local enemy = display.newCircle( spawnLocation.x, spawnLocation.y, settings.enemies.enemyName.size )
  enemy.type = "enemy"
  enemy.slot = #enemies + 1
  enemy.ID = numberOfEnemies + 1
  enemy.status = "alive" -- not currently needed but could be used for cc later
  enemy.surface = "ground" -- not currently needed but could be used for soundEFX and animations later
  enemy.usingStationaryWeapon = false
  enemy.HP = settings.enemies.enemyName.maxHP
  --local enemyName = display.newText( tostring( enemy.ID ), enemy.x, enemy.y, native.systemFont, 100 ) -- doesnt follow the unit
  enemy:setFillColor(1,0,0)

  camera:add( enemy, 1 )
  --camera:add( enemyName, 1 )

  physics.addBody( enemy, "dynamic", {bounce = 0, radius = settings.enemies.enemyName.size } )
  enemy.linearDamping = settings.player.friction
  enemy.angularDamping = settings.player.friction

  table.insert( enemies, enemy )
  numberOfEnemies = numberOfEnemies + 1
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
    --print(toDeg(angle)) -- q1 is -90 to 0
                        -- q2 is 0 to 90
                        -- q3 is 90 to 180
                        -- q4 is -180 to -90

    -- Move player
    local xForce = math.cos( angle ) * settings.guns[player.gun].recoil * -1
    local yForce = math.sin( angle ) * settings.guns[player.gun].recoil * -1
    player:applyLinearImpulse( xForce, yForce, player.x, player.y )
    player.rotation = (toDeg(angle)) -- Set player rotation


    if ( settings.guns[player.gun].projectile ) then
      -- Projectile weapons
      shootProjectile( angle, player.stationaryWeapon, player )
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
        print( "reloading ..." )
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

-- Function that handles shooting stationary weapons
function shootStationaryWeapon( event )
  if ( player.readyToFire == true )then
    local layer = camera:layer(1)
    local xDiff = event.x - ( player.x + layer.x )
    local yDiff = event.y - ( player.y + layer.y )
    local angle = math.atan2( yDiff, xDiff )

    if ( player.stationaryWeapon.table.projectile == true ) then
      -- Projectile weapons
      shootProjectile( angle, player.stationaryWeapon, player )
    elseif ( player.stationaryWeapon.table.projectile == false )then
      -- Non-projectile weapons
      shootNonProjectile( angle )
    end
    player.rotation = toDeg( angle )
    environment.miniGun.rotation = player.rotation

    -- Disable shooting
    player.readyToFire = false
    if ( player.ammo > 1 ) then
  --    ammoDisplay[player.ammo].isVisible = false
      player.ammo = player.ammo - 1
      timer.performWithDelay( player.stationaryWeapon.table.attackSpeed, function()
        player.readyToFire = true
      end )
    else -- reloading
    --    ammoDisplay[player.ammo].isVisible = false
        print( "reloading ..." )
        timer.performWithDelay( player.stationaryWeapon.table.reloadTime, function()
          player.ammo = player.stationaryWeapon.table.magazine
          player.readyToFire = true
        --  for i = 1, player.ammo, 1 do
        --    ammoDisplay[i].isVisible = true
        --  end
        end )
    end
  end
end
-- Handle bullet collision
function onBulletCollision( victim, source ) -- thing getting hit, and the thing hitting it
  if ( victim.type == "enemy" ) then
    local xForce = math.cos( toRad(player.rotation) ) * source.knockback
    local yForce = math.sin( toRad(player.rotation) ) * source.knockback
    victim:applyLinearImpulse( xForce, yForce, victim.x, victim.y ) -- knocks the victim back

    damage( victim, source.damage ) -- deals damage to enemy
    --print(victim.type .. " took " .. source.damage .. " damage from " .. source.name)
  end
 end

 -- Handle stepping on traps
 function trapTriggered( self, event ) -- event.target/self = trap
                                       -- event.other = victim
   local layer = camera:layer(1) -- i guess this is unnecessary?
                                 -- I dont understand why i dont need to add the layer.x/y value to the player coordinates, i did for the rectangle method
   local trap = self
   local victim = event.other
   local dx
   local dy

     if ( victim.type == "player" ) then -- if player steps on trap
       print( "player stepped on trap" )
     elseif ( victim.type == "enemy" ) then -- if enemy "steps" on trap
       print( "enemy " .. victim.ID .. " stepped on trap " )
     end

     function checkDistance()
       dx = victim.x - trap.x
       dy = victim.y - trap.y

       local distance = math.sqrt( dx*dx + dy*dy ) -- distance between trap circumference and victim's centre of mass
                                                   -- value is too high because this is calculated as soon as the objects touch, not continuesly
       if ( distance <= trap.path.radius ) then -- if victim origin is in trap
         damage( victim, victim.HP ) -- insta kill, damage equals vicim health
       elseif ( distance > trap.path.radius and distance <= trap.path.radius + victim.path.radius ) then
                                                       -- if victim is touching trap but origin is not inside
         timer.performWithDelay( 100,  checkDistance ) -- repeat check
       end
     end

     timer.performWithDelay( 100,  checkDistance ) -- need a delay or the distance value will be calculated on contact
 end

 -- CURRENTLY OBSOLETE
 --[[ Checks what surface a unit is on and what modifications to apply
 function checkSurface( character, surface ) -- all surfaces have to be rectangles for this to work
   local layer = camera:layer(1)

    if ( character.type == "player" ) then -- if player steps on surface
      if ( surface.contentBounds.xMin <= (character.x + layer.x) and surface.contentBounds.xMax >= (character.x + layer.x) and
           surface.contentBounds.yMin <= (character.y + layer.y) and surface.contentBounds.yMax >= (character.y + layer.y) ) then
           print("Player has stepped on: " .. surface.type)
           character.surface = surface.type
           surface.fn(character)
      end

    elseif ( character.type == "enemy" ) then -- if enemy steps on surface
      if ( surface.contentBounds.xMin <= (character.x) and surface.contentBounds.xMax >= (character.x) and
           surface.contentBounds.yMin <= (character.y) and surface.contentBounds.yMax >= (character.y) ) then
           print( "Enemy " .. character.ID .. " has stepped on: " .. surface.type)
           character.surface = surface.type
           surface.fn(character)
      end
    end
 end]]

-- FUNCTIONS FOR SURFACES
 -- Handles sliding across ice
 function onIce( self, event )
  local skater = event.other

  if (event.phase == "began") then -- when unit enters ice
    -- make them slip instantly
    skater.linearDamping = settings.environment.icyMountains.ice.friction
    skater.angularDamping = settings.environment.icyMountains.ice.friction
  elseif (event.phase == "ended") then -- when unit leaves ice
    -- make them STOP slipping instantly
    skater.linearDamping = settings.player.friction
    skater.angularDamping = settings.player.friction
  end
 end

 -- Handles slugging through mud
 function onMud( self, event )
   local victim = event.other

   if (event.phase == "began") then -- when unit enters mud
     -- make them slip instantly
     victim.linearDamping = settings.environment.swamp.mud.friction
     victim.angularDamping = settings.environment.swamp.mud.friction
   elseif (event.phase == "ended") then -- when unit leaves mud
     -- make them STOP slipping instantly
     victim.linearDamping = settings.player.friction
     victim.angularDamping = settings.player.friction
   end
 end

 function onGround( walker ) -- probably unnecessary but might be needed for the walking sound of different default surfaces
   walker.linearDamping = settings.player.friction
   walker.angularDamping = settings.player.friction
 end

-- FUNCTIONS FOR STATIONARY WEAPONS
  -- Snowball Mini-Gun
  function miniGun( self, event )
    local miniGun = self
    local pilot = event.other

    pilot.usingStationaryWeapon = true
    pilot.stationaryWeapon = miniGun

    if ( pilot.type == "player" )then -- if player mounted the weapon
      Runtime:removeEventListener("tap", shoot)
      pilot.ammo = miniGun.table.magazine
      timer.performWithDelay( 500, function() -- delay for animations and shit
        miniGun.isSensor = true
        pilot.x = miniGun.x
        pilot.y = miniGun.y
        pilot.rotation = miniGun.rotation
      --[[  for i = 1, player.ammo, 1 do -- will need to change shit when we have a different ammo icon
          ammoDisplay[i].isVisible = true
        end]]
        player.readyToFire = true
        Runtime:addEventListener("tap", shootStationaryWeapon)
      end)
    elseif ( pilot.type == "enemy" )then -- if enemy mounted weapon

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
      size = 60,
      defaultGun = "shotgun",
      friction = 3,
      maxHP = 100
    },

    enemies = {
      enemyName = {
        size = 60,
        maxHP = 250
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
        reloadTime = 3000, -- miliseconds
        attackSpeed = 300, -- minimum time between shots
        range = 400, -- Hypotneus value of the shot angle
        pelletCount = 5, -- number of pellets per shot
        spread = { -1/3, -1/6, 0, 1/6, 1/3 }, -- spread of the pellets
        shape = {0,0, 500,-300, 500,300},
        hitbox = {-250,0, 250,-300, 250,300},
        activeTime = 200,
        ammoIcon = "Assets/Pixel/weaponAssets/shotgunAmmo.png",
        ammoIconSize = {width = 50, height = 132}, -- vertical image, 2.65 ratio
        ammoIconSpacing = 70,
        audio = {
          shotgunReload = audio.loadStream("Assets/soundEFX/shotgunReload.wav"),
          shotgunPump = audio.loadStream("Assets/soundEFX/shotgunPump.wav"),
          shotgunBlast = audio.loadStream("Assets/soundEFX/shotgunBlast.wav")
        }
      }
    },

    stationaryWeapons = {
      miniGun = {
        name = "Snowball Mini-Gun",
        projectile = true,
        automatic = true,
        bulletSize = 10, -- radius of circle
        bulletSpeed = 50,
        recoil = 0,
        damage = 5,
        knockback = 1,
        magazine = 50,
        reloadTime = 10000,
        attackSpeed = 100,
        ammoIcon = "Assets/Pixel/weaponAssets/shotgunAmmo.png",
        ammoIconSize = {width = 50, height = 132}, -- vertical image, 2.65 ratio
        ammoIconSpacing = 70,
        audio = {}
      }
    },

    environment = {
      standardThickness = 50, -- standardThickness of a wall
      icyMountains = {
        ice = {
          friction = 0.5 -- the lower the value the slipperier the ice
        },
        majorBorders = { -- twice as thick as regular walls
          topBorderSize = 3000, -- anchored to origin
          leftBorderSize = 3000,
          rightBorderSize = 3000
        },
        internalWalls = {
          wall1Size = 400,
          wall2Size = 750,
          wall3Size = 400,
          wall4Size = 400,
          wall5Width = 400,  -- wall 5 is a custom polygon, this value refers to the absolute width of the shape
          wall5Height = 300, -- wall 5 is a custom polygon, this value refers to the absolute height of the shape
                             -- the above two values are calculated from the distance between verteces, not set,
                             -- changing them will just fuck up placement of the wall
          wall6Size = 400,
          wall7Size = 300,
          wall8Size = 600,
          wall9Size = 400
        },
        landIslands = {
          island1Size = 150,
          island2Size = 200,
          island3Size = 150
        }
      },
      swamp = {
        mud = {
          friction = 6
        }
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

  -----------------------------------------------------------------------------------------------------
  ---------------------------------------- LOAD ENVIRONMENT -------------------------------------------
  -----------------------------------------------------------------------------------------------------

  -- ICY MOUNTAINS
    -- ground (snow)
      -- every environment will have its own default surface for the sake of sound efx
      environment.snow = display.newRect( settings.environment.icyMountains.majorBorders.topBorderSize/-2, settings.environment.standardThickness, settings.environment.icyMountains.majorBorders.topBorderSize, settings.environment.icyMountains.majorBorders.rightBorderSize - settings.environment.standardThickness*2) -- placeholder values
      environment.snow.anchorX = environment.snow.x
      environment.snow.anchorY = environment.snow.y - environment.snow.height
      environment.snow.type = "ground"
      environment.snow.slot = #surfaces + 1
      environment.snow.fn = onGround
      environment.snow:setFillColor( 0.2, 0.2, 0.2 )
      camera:add( environment.snow, 2 )
      table.insert( surfaces, environment.snow1 )

    -- major borders
      environment.topBorder = display.newRect( 0, 0, settings.environment.icyMountains.majorBorders.topBorderSize, settings.environment.standardThickness * 2 ) -- anchor wall
      environment.leftBorder = display.newRect( (environment.topBorder.width / 2 + settings.environment.standardThickness)*-1,
        settings.environment.icyMountains.majorBorders.leftBorderSize/2 - settings.environment.standardThickness,
        settings.environment.standardThickness * 2, settings.environment.icyMountains.majorBorders.leftBorderSize ) -- anchored to topBorder
      environment.rightBorder = display.newRect( environment.topBorder.width / 2 + settings.environment.standardThickness,
        settings.environment.icyMountains.majorBorders.rightBorderSize/2 - settings.environment.standardThickness,
        settings.environment.standardThickness * 2, settings.environment.icyMountains.majorBorders.rightBorderSize ) -- anchored to topBorder

      environment.topBorder.type = "wall"
      environment.leftBorder.type = "wall"
      environment.rightBorder.type = "wall"

      physics.addBody( environment.topBorder, "static", {bounce = 0} )
      physics.addBody( environment.leftBorder, "static", {bounce = 0}  )
      physics.addBody( environment.rightBorder, "static", {bounce = 0}  )

      camera:add( environment.topBorder, 2 )
      camera:add( environment.leftBorder, 2 )
      camera:add( environment.rightBorder, 2 )

    -- internal walls
      environment.wall1 = display.newRect( settings.environment.icyMountains.majorBorders.topBorderSize/6, settings.environment.icyMountains.internalWalls.wall1Size/2 + settings.environment.standardThickness, settings.environment.standardThickness, settings.environment.icyMountains.internalWalls.wall1Size ) -- anchored to topBorder
      environment.wall2 = display.newRect( environment.wall1.x - settings.environment.icyMountains.internalWalls.wall2Size/2 + settings.environment.standardThickness/2, environment.wall1.y + environment.wall1.height/2 + settings.environment.standardThickness/2, settings.environment.icyMountains.internalWalls.wall2Size, settings.environment.standardThickness ) -- anchored to wall 1
      environment.wall3 = display.newRect( environment.wall2.x, environment.wall2.y + settings.environment.icyMountains.internalWalls.wall3Size/2 + settings.environment.standardThickness/2, settings.environment.standardThickness, settings.environment.icyMountains.internalWalls.wall3Size ) -- anchored to wall 2
      environment.wall5 = display.newPolygon( environment.wall3.x - settings.environment.icyMountains.internalWalls.wall5Width/2 + settings.environment.standardThickness/2, environment.wall3.y + environment.wall3.height/2 + settings.environment.icyMountains.internalWalls.wall5Height/2,   {-200, -100, 200, -100, 200, 200, -200, 0} ) -- (x, y, verticies), anchored to wall 3
      environment.wall6 = display.newRect( 500, 1025, settings.environment.standardThickness, 400 )
      environment.wall7 = display.newRect( environment.rightBorder.x - settings.environment.icyMountains.internalWalls.wall7Size/2 - settings.environment.standardThickness, settings.environment.icyMountains.majorBorders.rightBorderSize*1/3, settings.environment.icyMountains.internalWalls.wall7Size, settings.environment.standardThickness ) -- attached to rightBorder
      environment.wall8 = display.newRect( -900, 1600, settings.environment.standardThickness, 600 )
      environment.wall9 = display.newRect( 675, 1250, 400, settings.environment.standardThickness )

      environment.wall1.type = "wall"
      environment.wall2.type = "wall"
      environment.wall3.type = "wall"
      environment.wall5.type = "wall"
      environment.wall6.type = "wall"
      environment.wall7.type = "wall"
      environment.wall8.type = "wall"
      environment.wall9.type = "wall"

      physics.addBody( environment.wall1, "static", {bounce = 0} )
      physics.addBody( environment.wall2, "static", {bounce = 0} )
      physics.addBody( environment.wall3, "static", {bounce = 0} )
      physics.addBody( environment.wall5, "static", {bounce = 0} )
      physics.addBody( environment.wall6, "static", {bounce = 0} )
      physics.addBody( environment.wall7, "static", {bounce = 0} )
      physics.addBody( environment.wall8, "static", {bounce = 0} )
      physics.addBody( environment.wall9, "static", {bounce = 0} )

      camera:add( environment.wall1, 2 )
      camera:add( environment.wall2, 2 )
      camera:add( environment.wall3, 2 )
      camera:add( environment.wall5, 2 )
      camera:add( environment.wall6, 2 )
      camera:add( environment.wall7, 2 )
      camera:add( environment.wall8, 2 )
      camera:add( environment.wall9, 2 )

   -- land islands
      environment.island1 = display.newRect( environment.topBorder.width /-4, environment.topBorder.y + settings.environment.icyMountains.landIslands.island1Size/2 + settings.environment.standardThickness, settings.environment.standardThickness*2, settings.environment.icyMountains.landIslands.island1Size ) -- anchored to topBorder
      environment.island2 = display.newRect( settings.environment.icyMountains.majorBorders.topBorderSize /3, settings.environment.icyMountains.majorBorders.rightBorderSize /5, settings.environment.icyMountains.landIslands.island2Size, settings.environment.standardThickness*2 ) -- x is anchored to topBorder, y is anchored to rightBorder
      environment.island3 = display.newRect( settings.environment.icyMountains.majorBorders.topBorderSize * 2/-5, settings.environment.icyMountains.majorBorders.leftBorderSize /5, settings.environment.icyMountains.landIslands.island3Size, settings.environment.standardThickness*2 ) -- x is anchored to topBorder, y is anchored to leftBorder

      environment.island1.type = "wall"
      environment.island2.type = "wall"
      environment.island3.type = "wall"

      physics.addBody( environment.island1, "static", {bounce = 0} )
      physics.addBody( environment.island2, "static", {bounce = 0} )
      physics.addBody( environment.island3, "static", {bounce = 0} )

      camera:add( environment.island1, 2 )
      camera:add( environment.island2, 2 )
      camera:add( environment.island3, 2 )

  -- TERRAIN
    -- TRAPS
      environment.iceTrap = display.newCircle( -800, 600, 150 )
      environment.iceTrap.type = "trap"
      environment.iceTrap.slot = #traps + 1
      camera:add( environment.iceTrap, 2 )
      physics.addBody( environment.iceTrap, "static", {bounce = 0, isSensor = true, radius = 150, filter = {groupIndex = -1} } )
      environment.iceTrap.collision = trapTriggered
      environment.iceTrap:addEventListener( "collision" )
      table.insert( traps, environment.iceTrap )

    -- SURFACES
      environment.ice1 = display.newRect( environment.wall1.x - 800, environment.wall1.y, 800, environment.wall1.height ) -- not exact coordinates
      environment.ice1.type = "ice"
      environment.ice1.slot = #surfaces + 1
      environment.ice1.fn = onIce
      environment.ice1:setFillColor( 0, 0.6, 0.8 )
      camera:add( environment.ice1, 2 )
      physics.addBody( environment.ice1, "static", {bounce = 0, isSensor = true, filter = {groupIndex = -1} } )
      environment.ice1.collision = onIce
      environment.ice1:addEventListener( "collision" )
      table.insert( surfaces, environment.ice1 )

  -- STATIONARY WEAPONS
   -- Snowball Mini-Gun
      environment.miniGun = display.newCircle( environment.island3.x, environment.island3.y - 300, 100 )
      environment.miniGun.type = "stationary weapon"
      environment.miniGun.slot = #stationaryWeapons + 1
      environment.miniGun.table = settings.stationaryWeapons.miniGun

      environment.miniGun:setFillColor( 0.4, 0.4, 0.4 )
      camera:add( environment.miniGun, 2 )
      physics.addBody( environment.miniGun, "static", {bounce = 0, radius = 100, filter = {groupIndex = -1} } )
      environment.miniGun.collision = miniGun
      environment.miniGun:addEventListener( "collision" )
      table.insert( stationaryWeapons, environment.miniGun )

  -- Load enemy spawns
  environment.enemySpawns = {
    --{ x = 600, y = 200 },
    --{ x = 400, y = 400 },
    { x = -575, y = 600 }
  }

  -- Load the player
  player = display.newCircle( display.contentCenterX - 1000, display.contentCenterY - 200, settings.player.size )
  player.gun = settings.player.defaultGun
  player.readyToFire = true
  player.ammo = settings.guns[player.gun].magazine
  player.type = "player"
  player.usingStationaryWeapon = false
  player.HP = settings.player.maxHP
  player.surface = "ground"
  player:setFillColor(0,0,1)

  physics.addBody( player, "dynamic", {bounce = 0, radius = settings.player.size } )
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
  --Runtime:addEventListener( "enterFrame", gameLoop )
end


-- Runs when scene is fully loaded
function scene:show( event )
  if ( event.phase == "did" ) then
    -- start the physics engine
    physics.start()
    -- START SPAWNING ENEMIES CHANGE THIS NOT FUTURE PROOF
    enemyGenerator = timer.performWithDelay( settings.game.spawnTime, spawnEnemy, -1 )

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
