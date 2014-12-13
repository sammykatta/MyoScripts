scriptId = 'com.curiousg.scripts.betterppt'
scriptDetailsUrl = ''
scriptTitle = 'Better PowerPoint Connector'

function onForegroundWindowChange(app, title)
    return platform == "MacOS" and app == "com.microsoft.Powerpoint" or
       platform == "Windows" and (app == "POWERPNT.EXE" or app == "PPTVIEW.EXE")
end

function activeAppName()
    return "PowerPoint"
end

-- flag to de/activate shuttling feature
supportShuttle = true

-- Effects

function forward()
    myo.keyboard("down_arrow", "press")
end

function backward()
    myo.keyboard("up_arrow", "press")
end

function eraseInk()
	myo.keyboard("e", "press")
end

function hideInk()
	myo.keyboard ("m", "press", "control")
end

-- Mouse clicks
function mouseOn()
	myo.controlMouse(true)
	-- myo.debug("mouse should be enabled")
end

function mouseOff()
	myo.controlMouse(false)
	myo.unlock("timed")
	penSince = nil
	arrowSince = nil
	-- myo.debug("mouse should be disabled")
end

function leftClickDown()
	myo.mouse("left", "down")
	penSince = myo.getTimeMilliseconds()
	-- myo.debug("am I drawing?")
end

function leftClickUp()
	myo.mouse("left", "up")
end


-- Helpers

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

-- Shuttle

function shuttleBurst()
    if shuttleDirection == "forward" then
        forward()
    elseif shuttleDirection == "backward" then
        backward()
    end
end

--  Pen mode
function penModeOn()
	myo.keyboard("p", "press", "control")
	penSince = myo.getTimeMilliseconds()
	mouseOn()
end

function arrowModeOn()
	mouseOn()
	arrowSince = myo.getTimeMilliseconds()
	myo.centerMousePosition()
end

function exitModes()
	currentMode = nil
	myo.keyboard("a", "press", "control")
	mouseOff()
	myo.unlock("timed")
end

-- Triggers

function onPoseEdge(pose, edge)
    -- Forward/backward and shuttle
    if pose == "waveIn" or pose == "waveOut" then
        local now = myo.getTimeMilliseconds()

        if edge == "on" then
            -- Deal with direction and arm
            pose = conditionallySwapWave(pose)

			-- If in pen mode, wave in/out should get rid of ink
			if currentMode == "pen" then
				if pose == "waveIn" then
					eraseInk()
				elseif pose == "waveOut" then
					hideInk()
				end
			
			-- If in arrow mode or no specific mode, normal slide advance
			elseif not currentMode then		
				if pose == "waveIn" then
					shuttleDirection = "backward"
					-- myo.debug("back")
				else
					shuttleDirection = "forward"
				end

				-- Extend unlock and notify user
				myo.unlock("hold")
				myo.notifyUserAction()

				-- Initial burst
				shuttleBurst()
				shuttleSince = now
				shuttleTimeout = SHUTTLE_CONTINUOUS_TIMEOUT
			end
			
        end
		
        if edge == "off" then
            myo.unlock("timed")
            shuttleTimeout = nil
        end
		
    end
	if pose == "fingersSpread" then
		local now = myo.getTimeMilliseconds()
		
		if edge == "off" then
			
			-- If this is the first time you do the fingersSpread gesture, 
			-- enter command mode
			if not currentMode then
				currentMode = "command"
				commandSince = now
				myo.unlock("hold")
			-- If you are in command mode and you do the spread gesture
			-- again, then enter arrow mode
			elseif currentMode == "command" then
				arrowModeOn()
				currentMode = "arrow"
			-- Use fingersSpread to exit pen or arrow mode
			elseif currentMode == "pen" or currentMode == "arrow" then 
				exitModes()
			end
			
		end
		
	end
	if pose == "fist" then
	
	-- Turn on pen mode if you are in command mode, or start drawing
	-- if you're already in pen mode.
	if currentMode == "command" then
		currentMode = "pen"
		penModeOn()	
	elseif currentMode == "pen" then
		if edge == "on" then
			leftClickDown()
		elseif edge == "off" then
			leftClickUp()
		end
	end
			
	end
end

-- All timeouts in milliseconds
SHUTTLE_CONTINUOUS_TIMEOUT = 600
SHUTTLE_CONTINUOUS_PERIOD = 300
COMMAND_TIMEOUT = 600
PEN_TIMEOUT = 5000
ARROW_TIMEOUT = 5000

function onPeriodic()
    local now = myo.getTimeMilliseconds()
    if supportShuttle and shuttleTimeout then
        if (now - shuttleSince) > shuttleTimeout then
            shuttleBurst()
            shuttleTimeout = SHUTTLE_CONTINUOUS_PERIOD
            shuttleSince = now
        end
    end
	
	if currentMode == "command" then
		-- Exit command mode if it's been a while.
		if (now - commandSince) > COMMAND_TIMEOUT then
			currentMode = nil
			myo.unlock("timed")
		end
	elseif currentMode == "pen" then
		if (now - penSince) > PEN_TIMEOUT then
			exitModes()
		end
	elseif currentMode == "arrow" then
		if (now - arrowSince) > ARROW_TIMEOUT then
			exitModes()
		end
	end
end