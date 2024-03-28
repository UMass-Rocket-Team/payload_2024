local HOME_SET_TRIGGER_THRESHOLD = 1500 -- This needs to be changed in testing
local HOME_TRIGGER_CHANNEL = 11 -- This also needs to be set
local FEET_IN_METER = 3.281

function check_for_home_trigger()
    -- this comparison may need to be flipped
    if rc:get_pwm(HOME_TRIGGER_CHANNEL) > HOME_SET_TRIGGER_THRESHOLD then
        ahrs:set_home(ahrs:get_location())
        return print_altitude, 250
    end

    return check_for_home_trigger, 250
end

function print_altitude()
    local dist = ahrs:get_relative_position_NED_home()
    local altitudeMeters = -1 * dist:z()
    local altitudeFeet = altitudeMeters / FEET_IN_METER
    gcs:send_text(0, "Altitude (ft): " .. altitudeFeet)
    return print_altitude, 250
end
    

return check_for_home_trigger, 1000