scriptId = 'com.thalmic.scripts.presentation'
scriptDetailsUrl = 'https://market.myo.com/app/5474c658e4b0361138df2a9e'
scriptTitle = 'PowerPoint Connector'

function onForegroundWindowChange(app, title)
    return platform == "MacOS" and app == "com.microsoft.Powerpoint" or
       platform == "Windows" and (app == "POWERPNT.EXE" or app == "PPTVIEW.EXE")
end

function activeAppName()
    return "PowerPoint"
end

-- flag to de/activate shuttling feature
supportShuttle = false

-- Effects

function forward()
    myo.keyboard("down_arrow", "press")
end

function backward()
    myo.keyboard("up_arrow", "press")
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

-- Triggers

function onPoseEdge(pose, edge)
    -- Forward/backward and shuttle
    if pose == "waveIn" or pose == "waveOut" then
        local now = myo.getTimeMilliseconds()

        if edge == "on" then
            -- Deal with direction and arm
            pose = conditionallySwapWave(pose)

            if pose == "waveIn" then
                shuttleDirection = "backward"
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
        if edge == "off" then
            myo.unlock("timed")
            shuttleTimeout = nil
        end
    end
end

-- All timeouts in milliseconds
SHUTTLE_CONTINUOUS_TIMEOUT = 600
SHUTTLE_CONTINUOUS_PERIOD = 300

function onPeriodic()
    local now = myo.getTimeMilliseconds()
    if supportShuttle and shuttleTimeout then
        if (now - shuttleSince) > shuttleTimeout then
            shuttleBurst()
            shuttleTimeout = SHUTTLE_CONTINUOUS_PERIOD
            shuttleSince = now
        end
    end
end