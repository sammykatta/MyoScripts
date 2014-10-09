scriptId = 'com.sammy.scripts.spotifycontrol'

-- Effects

function forward()
    myo.keyboard("right_arrow", "press", "control")
end

function backward()
    myo.keyboard("left_arrow", "press", "control")
end

function playPause()
	myo.keyboard("space", "press")
end

function volumeUp()
	myo.keyboard("up_arrow", "press", "control")
end

function volumeDown()
	myo.keyboard("down_arrow", "press", "control")
end

-- Burst forward or backward depending on the value of shuttleDirection.
function shuttleBurst()
    if shuttleDirection == "forward" then
        forward()
    elseif shuttleDirection == "backward" then
        backward()
    end
end

-- Turn volume one notch up or down depending on value of volDirection.
function volBurst()
	if volDirection == "up" then
		volumeUp()
	elseif volDirection == "down" then
		volumeDown()
	end
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

function relock()
	unlocked = false
end

function extendUnlock()
    unlockedSince = myo.getTimeMilliseconds()
end

-- Implement Callbacks

function onPoseEdge(pose, edge)
    -- Unlock
    if pose == "thumbToPinky" then
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
    end

	-- Play and pause
	if pose == "fingersSpread" then
		if unlocked and edge == "on" then
			playPause()
			relock()
		end
	end
	
    -- Forward/backward and shuttle.
    if pose == "waveIn" or pose == "waveOut" then
        local now = myo.getTimeMilliseconds()

        if unlocked and edge == "on" then
            -- Deal with direction and arm.
            pose = conditionallySwapWave(pose)

            -- Determine direction based on the pose.
            if pose == "waveIn" then
                shuttleDirection = "backward"
            else
                shuttleDirection = "forward"
            end

            -- Initial burst and vibrate
            myo.vibrate("short")
            shuttleBurst()

        end
        -- If we're no longer making wave in or wave out, stop shuttle behaviour.
        if edge == "off" then
            shuttleTimeout = nil
        end
    end
	
	if pose == "fist" then
		local now = myo.getTimeMilliseconds()
		yawStart = myo.getYaw()
		-- myo.debug("Start Position: " .. yawStart)
		
		if unlocked and edge == "on" then
			-- Set up volume control behaviour. Start with the longer timeout for 
            -- the initial delay.
            volSince = now
            volTimeout = VOL_CONTROL_TIMEOUT
            extendUnlock()
		end
		
		-- If we're no longer holding the fist, stop changing volume
		if edge == "off" then
			volTimeout = nil
			relock()
		end
		
	end

end

-- All timeouts in milliseconds.

-- Time since last activity before we lock
UNLOCKED_TIMEOUT = 2200

-- Delay when holding wave left/right before switching to shuttle behaviour
VOL_CONTROL_TIMEOUT = 600

-- How often to trigger shuttle behaviour
VOL_CONTROL_PERIOD = 300

function onPeriodic()
    local now = myo.getTimeMilliseconds()
	local yawNow = myo.getYaw()
	
	
    -- Volume change behaviour
    if volTimeout then
        extendUnlock()

        -- If we haven't done a volume burst since the timeout, do one now
        if (now - volSince) > volTimeout then
			-- myo.debug("Current yaw: " .. yawNow-yawStart)
            --  Check if user has rotated their arm since making the fist, 
			-- and assign volume direction based on direction of rotation.
				if yawNow - yawStart < -0.1 then
					volDirection = "up"
					volBurst()
				elseif yawNow - yawStart > 0.1 then
					volDirection = "down"
					volBurst()
				end

            -- Update the timeout. (The first time it will be the longer delay.)
            volTimeout = VOL_CONTROL_PERIOD

            -- Update when we did the last volume burst
            volSince = now
        end
    end

    -- Lock after inactivity
    if unlocked then
        -- If we've been unlocked longer than the timeout period, lock.
        -- Activity will update unlockedSince, see extendUnlock() above.
        if myo.getTimeMilliseconds() - unlockedSince > UNLOCKED_TIMEOUT then
            unlocked = false
        end
    end
end

function onForegroundWindowChange(app, title)
    -- Here we decide if we want to control the new active app.
    local wantActive = false
    activeApp = ""

    if platform == "Windows" then
        -- Spotify on Windows
        wantActive = string.match(title, "Spotify") 
        activeApp = "Spotify"
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