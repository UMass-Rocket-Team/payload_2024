

local scripting_rc_1 = rc:find_channel_for_option(300)
local scripting_rc_2 = rc:find_channel_for_option(301)


function update ()

chval = tostring(rc:get_pwm(11))

  

  return update, 250
end
return update, 1000


