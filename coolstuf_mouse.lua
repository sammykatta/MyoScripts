scriptId = 'com.coolstuf.mouse'
-- Copied from https://github.com/matttbates/lua-scripts-for-myo/blob/master/mouse.lua
-- on Oct 18, 2014.

-- Effects 

function rightClick()
    	myo.mouse("right", "down")
end

function unRightClick()
    	myo.mouse("right", "up")
end

function leftClick()
    	myo.mouse("left", "click")
end

function middleClick()
	myo.mouse("center", "click")
end

function dragClick()
	myo.mouse("left", "down")
end

function unDragClick()
    	myo.mouse("left", "up")
end

-- Unlock mechanism 

function unlock()
    	unlocked = true
	myo.controlMouse(true)
end

function relock()
	unlocked = false
	myo.controlMouse(false)
end

-- Implement Callbacks 

function onPoseEdge(pose, edge)

-- Unlock
    	if pose == "thumbToPinky" then
		if unlocked == false then
  	    		if edge == "off" then
    	        		unlock()
    	    		elseif edge == "on" then
     	       			myo.vibrate("short")
     	       			myo.vibrate("short")
     	    		end
		elseif unlocked == true then
			if edge == "off" then
    	        		relock()
    	    		elseif edge == "on" then
     	       			myo.vibrate("short")
     	    		end
		end
    	end

-- left button
	if pose == "fingersSpread" then
		if unlocked and edge == "on" then
			leftClick()	
		end
	end
	
-- middle click
    	if pose == "waveIn" then 
        	if unlocked and edge == "on" then
                	middleClick()
            	end
	end

-- right click
	if pose == "waveOut" then
                if unlocked and edge == "on" then	
			rightClick()
             	elseif unlocked and edge == "off" then
                	unRightClick()
            	end
    	end

-- drag click
	if pose == "fist" then
		if unlocked and edge == "on" then
			dragClick()
		elseif unlocked and edge == "off" then
			unDragClick()
		end
	end

end

function onPeriodic()
	if myo.getArm() == "unknown" then
		relock()
	end
end

function onForegroundWindowChange(app, title)
	appName = title
	if myo.getArm() == "unknown" then
		relock()
		return false
	else
		return true
	end
end

function onActiveChange(isActive)
	unlocked = false
end


