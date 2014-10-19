scriptId = 'com.curiousg.scripts.betterppt'

-- Progress: 
-- Command mode/mode switching set up, but exiting pen/arrow/command mode doesn't
	-- work consistently (though arrow exit works better than the others).
-- Disabling mouse control is hit or miss, mostly miss.
-- Left click down for drawing when in pen mode doesn't work for some reason.
-- Have yet to test erase/hide ink because I haven't gotten it to draw yet.
-- Need to add check for Mac vs. PC for relevant keyboard functions.

-- This script is based off the powerpoint presentation sample script offered by Thalmic,
-- and the mouse control script by matttbates.

-- Should work on Mac, but hasn't been tested because I don't have one. 

-- Effects 

function nextSlide()
    myo.keyboard("down_arrow", "press")
end

function prevSlide()
    myo.keyboard("up_arrow", "press")
end

-- Burst forward or backward.
function shuttleBurst()
    if shuttleDirection == "forward" then
        nextSlide()
    elseif shuttleDirection == "backward" then
        prevSlide()
    end
end

-- Mouse clicks
function mouseOn()
	myo.controlMouse(true)
end

function mouseOff()
	myo.controlMouse(false)
	myo.debug("mouse should be disabled")
end

function leftClickDown()
	myo.mouse("left", "down")
end

function leftClickUp()
	myo.mouse("left", "up")
end

--  Pen mode
function penModeOn()
	myo.keyboard("p", "press", "control")
	mouseOn()
end

function arrowModeOn()
	myo.keyboard("a", "press", "control")
	mouseOn()
	myo.centerMousePosition()
end

function eraseInk()
	myo.keyboard("e", "press")
end

function hideInk()
	myo.keyboard ("m", "press", "control")
end

-- Helpers

-- Makes use of myo.getArm() to swap wave out and wave in when the armband is being worn on
-- the left arm. This allows us to treat wave out as wave right and wave in as wave
-- left for consistent direction. The function has no effect on other poses.
function conditionallySwapWave(pose)
    if myo.getArm() == "left" then
        if pose == "waveIn" then
            pose = "waveOut"
        elseif pose == "waveOut" then
            pose = "waveIn"
        end
    end
    return pose
end

-- Unlock mechanism 

function unlock()
    unlocked = true
    extendUnlock()
end

function extendUnlock()
    unlockedSince = myo.getTimeMilliseconds()
end

function relock()
	unlocked = false
	mouseOff()
end

-- Implement Callbacks 

function onPoseEdge(pose, edge)

-- Unlock and relock
    if pose == "thumbToPinky" then
		if not unlocked then
			if edge == "off" then
				-- Unlock when pose is released in case the user holds it for a while.
				unlock()
			elseif edge == "on" and not unlocked then
				-- Vibrate twice on unlock.
				-- We do this when the pose is made for better feedback.
				myo.vibrate("short")
				myo.vibrate("short")
				extendUnlock()
			end
		-- elseif unlocked then
			-- if edge == "off" then
				-- relock()
			-- elseif edge == "on" then
				-- myo.vibrate("short")
			-- end
		end
    end

-- Forward/backward and shuttle, erase and hide ink.
    if pose == "waveIn" or pose == "waveOut" then
        local now = myo.getTimeMilliseconds()

        if unlocked and edge == "on" then
            -- Deal with direction and arm.
            pose = conditionallySwapWave(pose)

			if currentMode == "pen" then
				if pose == "waveIn" then
					eraseInk()
				elseif pose == "waveOut" then
					hideInk()
				end
			end
			
            -- Determine direction based on the pose.
            if pose == "waveIn" then
                shuttleDirection = "backward"
            else
                shuttleDirection = "forward"
            end

            -- Initial burst and vibrate
            myo.vibrate("short")
            shuttleBurst()

            -- Set up shuttle behaviour. Start with the longer timeout for the initial
            -- delay.
            shuttleSince = now
            shuttleTimeout = SHUTTLE_CONTINUOUS_TIMEOUT
            extendUnlock()
        end
        -- If we're no longer making wave in or wave out, stop shuttle behaviour.
        if edge == "off" then
            shuttleTimeout = nil
        end
    end

-- Toggle command mode, move mouse arrow around
	if pose == "fingersSpread" then
	myo.debug("pose = " .. pose .. ", edge = " .. edge .. ", mode = " .. currentMode)

        local now = myo.getTimeMilliseconds()
	
		if unlocked and edge == "off" then
		
		-- If this is the first time you do the fingersSpread gesture, 
		-- enter command mode
			if not currentMode then
				currentMode = "command"
				commandSince = now
		-- If you are in command mode and you do the spread gesture
		-- again, then enter arrow mode
			elseif currentMode == "command" then
				arrowModeOn()
				currentMode = "arrow"
		-- Use fingersSpread to exit pen or arrow mode
			elseif currentMode == "pen" then 
				currentMode = nil
				mouseOff()			
			elseif currentMode == "arrow" then
				currentMode = nil
				mouseOff()
			end
		myo.debug("mode after spread = " .. currentMode)
		end
					
	end
	
-- Draw on screen
	if pose == "fist" then
	myo.debug("pose = " .. pose .. ", edge = " .. edge)

		if unlocked then
		
		-- Turn on pen mode if you are in command mode, or start drawing
		-- if you're already in pen mode.
			if currentMode == "command" then
				currentMode = "pen"
				penModeOn()	
				extendUnlock()
				myo.debug("mode after fist = " .. currentMode)
			elseif currentMode == "pen" then
				if edge == "on" then
					leftClickDown()
				elseif edge == "off" then
					leftClickUp()
				end
			end
			
		end

	end

end
-- All timeouts in milliseconds.

-- Time since last activity before we lock
UNLOCKED_TIMEOUT = 2200
PEN_UNLOCKED_TIMEOUT = 5000

-- Delay when holding wave left/right before switching to shuttle behaviour
SHUTTLE_CONTINUOUS_TIMEOUT = 600

-- How often to trigger shuttle behaviour
SHUTTLE_CONTINUOUS_PERIOD = 300

-- Wait time after activating pen command option before reverting back to normal controls
COMMAND_TIMEOUT = 600


function onPeriodic()
    local now = myo.getTimeMilliseconds()
	
	-- NOT SURE IF THIS BIT IS NECESSARY
	-- if myo.getArm() == "unknown" then
		-- relock()
	-- end
 
	-- Command mode behavior
	if currentMode == "command" then
		-- Exit command mode if it's been a while.
		if (now - commandSince) > COMMAND_TIMEOUT then
			currentMode = nil
		end
	end
	
    -- Shuttle behaviour
    if shuttleTimeout then
        extendUnlock()

        -- If we haven't done a shuttle burst since the timeout, do one now
        if (now - shuttleSince) > shuttleTimeout then
            --  Perform a shuttle burst
            shuttleBurst()

            -- Update the timeout. (The first time it will be the longer delay.)
            shuttleTimeout = SHUTTLE_CONTINUOUS_PERIOD

            -- Update when we did the last shuttle burst
            shuttleSince = now
        end
    end

    -- Lock after inactivity
    if unlocked then
        -- If we've been unlocked longer than the timeout period, lock.
        -- Activity will update unlockedSince, see extendUnlock() above.		
		if currentMode == "pen" then
			local timeout = PEN_UNLOCKED_TIMEOUT
		else
			local timeout = UNLOCKED_TIMEOUT
		end
			
		if now - unlockedSince > timeout then
			unlocked = false
			currentMode = nil
			mouseOff()
		end

    end
end

function onForegroundWindowChange(app, title)
    -- Here we decide if we want to control the new active app.
    local wantActive = false
    activeApp = ""

    if platform == "MacOS" then
        if app == "com.apple.iWork.Keynote" then
            -- Keynote on MacOS
			-- This name was a Uniform Type Identifier, or UTI, used by Apple stuff
            wantActive = true
            activeApp = "Keynote"
        elseif app == "com.microsoft.Powerpoint" then
            -- Powerpoint on MacOS
            wantActive = true
            activeApp = "Powerpoint"
        end
    elseif platform == "Windows" then
        -- Powerpoint on Windows
		-- This is just a window title match
        wantActive = string.match(title, " %- PowerPoint$") or
                     string.match(title, "^PowerPoint Slide Show %- ") or
                     string.match(title, " %- PowerPoint Presenter View$")
        activeApp = "Powerpoint"
    end
    return wantActive
end

function activeAppName()
    -- Return the active app name determined in onForegroundWindowChange
    return activeApp
end

function onActiveChange(isActive)
    if not isActive then
        unlocked = false
    end
end

