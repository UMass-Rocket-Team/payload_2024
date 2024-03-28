local FEET_IN_METER = 3.281

function run_alt()
    local dist = ahrs:get_relative_position_NED_home()
    local altitudeMeters = -1*dist:z()
    local altitudeFeet = altitudeMeters / FEET_IN_METER
    gcs:send_text(0, "Altitude (ft): " .. altitudeFeet)
end

function startup()
    ahrs:set_home(ahrs:get_location())
    return run_alt, 1000
end

return startup, 1000