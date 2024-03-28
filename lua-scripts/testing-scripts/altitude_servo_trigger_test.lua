local METERS_TO_FEET 3.281
--------Servo Positions---------
--(likely need to be updated)---
local LOCKED_PAYLOAD_SERVO_POS = 1000
local UNLOCKED_PAYLOAD_SERVO_POS = 2000
local LOCKED_CONE_SERVO_POS = 1000
local UNLOCKED_CONE_SERVO_POS = 2000

-------------Servos-------------
local PAYLOAD_RETENTION_SERVO = 96
local CONE_RETENTION_SERVO = 97
local payload_servo_channel = SRV_Channels:find_channel(PAYLOAD_RETENTION_SERVO)
local cone_servo_channel = SRV_Channels:find_channel(CONE_RETENTION_SERVO)

------------Constants-----------
local MAX_NOSECONE_DEPLOYMENT_ALT = 8
local MAX_PAYLOAD_DEPLOYMENT_ALT = 5


function run_alt()
    local dist = ahrs:get_relative_position_NED_home()
    local altitudeMeters = -1*dist:z()
    local altitudeFeet = altitudeMeters * METERS_TO_FEET
    gcs:send_text(0, "Altitude (ft): " .. altitudeFeet)
    if MAX_NOSECONE_DEPLOYMENT_ALT > altitudeFeet
        SRV_Channels:set_output_pwm(cone_servo_channel, UNLOCKED_CONE_SERVO_POS)
        gcs:send_text(0, "Nosecone Unlocked")
    else --else usage not great practice, but just for testing...
        SRV_Channels:set_output_pwm(cone_servo_channel, LOCKED_CONE_SERVO_POS)
    end

    if MAX_PAYLOAD_DEPLOYMENT_ALT > altitudeFeet
        SRV_Channels:set_output_pwm(payload_servo_channel, UNLOCKED_PAYLOAD_SERVO_POS)
        gcs:send_text(0, "Payload Unlocked")
    else --else usage not great practice, but just for testing...
        SRV_Channels:set_output_pwm(payload_servo_channel, LOCKED_PAYLOAD_SERVO_POS)
    end
end

function startup()
    ahrs:set_home(ahrs:get_location())
    return run_alt, 250
end

return startup, 1000