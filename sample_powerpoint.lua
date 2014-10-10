scriptId = 'com.thalmic.scripts.presentation'

-- Effects

function forward()
    myo.keyboard("down_arrow", "press")
end

function backward()
    myo.keyboard("up_arrow", "press")
end

-- Burst forward or backward depending on the value of shuttleDirection.
function shuttleBurst()
    if shuttleDirection == "forward" then
        forward()
    elseif shuttleDirection == "backward" then
        backward()
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
end

-- All timeouts in milliseconds.

-- Time since last activity before we lock
UNLOCKED_TIMEOUT = 2200

-- Delay when holding wave left/right before switching to shuttle behaviour
SHUTTLE_CONTINUOUS_TIMEOUT = 600

-- How often to trigger shuttle behaviour
SHUTTLE_CONTINUOUS_PERIOD = 300

function onPeriodic()
    local now = myo.getTimeMilliseconds()

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
        if myo.getTimeMilliseconds() - unlockedSince > UNLOCKED_TIMEOUT then
            unlocked = false
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