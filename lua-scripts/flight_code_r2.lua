-- 1000ft AGL drone is armed
-- 700ft main chute comes out
-- 600 or 650ft nosecone deploys
-- 500ft payload deploys

-- radio channel 6 IS NOSECONE
-- radio channel 8 IS PAYLOAD
-- radio channel 13 IS SET HOME

-- ALL UNITS ARE SI UNLESS OTHERWISE SPECIFIED

-- --------------------------------------------------
-- location values

local baro_alt_asl -- filtered altitude above sea levelcalculated only from barometer
local baro_alt_agl -- filtered altitude above ground level only from barometer
local ekf_alt_agl -- altitude from the EKF relative to launchpad
local alt_agl -- the best estimate of the altitude above ground level 

-- running average altitude filtering data
local baro_ringbuff_arr = {} -- ringbuffer array
local baro_ringbuff_idx = 1 -- current ringbuffer index
local baro_running_alt_n_samples = 30 -- number of samples to average over

-- barometer offset variables
local baro_alt_offset -- offset between true starting altitude and barometric reading
local baro_alt_offset_tmp = 0 -- temporary offset value while averaging
local baro_offset_alt_sample_num = 0 -- current sample index
local baro_offset_alt_n_samples = 100 -- number of samples to take

-- landing zone position variables
local position_target_landing = Location()

-- field in amherst
-- position_target_landing:lat(423790080)
-- position_target_landing:lng(-725136008)

-- tenative landing zone
-- position_target_landing:lat(348954070)
-- position_target_landing:lng(-866183470)

-- landing zone as of night before launch
position_target_landing:lat(348954069)
position_target_landing:lng(-866183745)

local altitude_launchpad
local altitude_launchpad_tmp = 0.0 -- temporary position of the launchpad while averaging
local position_launchpad_sample_num = 0 -- current sample index
local position_launchpad_n_samples = 100 -- number of samples to take

-- --------------------------------------------------
-- servo control variables

-- timing values
local servo_wiggle_delay_ms = 1000 -- time in ms between "wiggles" on the servos

-- angle values for nosecone and payload
local servo_deployed_value_nosecone = 1700 -- deployment value in microseconds for nosecone
local servo_deployed_value_payload = 1300 -- deployment value in microseconds for payload
local servo_stowed_value_nosecone = 1000 -- stowing value in microseconds for nosecone
local servo_stowed_value_payload = 2000 -- stowing value in microseconds for payload

-- state values
local servo_angle_nosecone_cur = servo_deployed_value_nosecone -- current angle of the nosecone servo
local servo_angle_payload_cur = servo_deployed_value_payload -- current angle of the payload servo
local servo_last_wiggle_time_payload_ms = 0 -- time of the last "wiggle" from deployed to stowed positions on both servos
local servo_last_wiggle_time_nosecone_ms = 0 -- time of the last "wiggle" from deployed to stowed positions on both servos

-- deployment altitude constants
local deployment_altitude_nosecone_ft = 600 -- altitude to start the deployment sequence for the nosecone
local deployment_altitude_payload_ft = 400 -- altitude to start the deployment sequence for the payload
local deployment_floor_nosecone_ft = 400 -- dont deploy nosecone under 400ft
local deployment_floor_payload_ft = 175 -- dont deploy payload under 175ft

-- state values
local vehicle_mode_guided = 4
local vehicle_mode_RTL = 6

-- --------------------------------------------------
-- location flags

local baro_initial_offset_lock = false -- true if the barometer offset value has been calculated
local baro_initial_average_lock = false -- true if the running average filter has been initialized
local launchpad_initial_position_lock = false -- true if the launchpad position has been found
local ekf_estimate_valid = false -- true if the EKF has a position estimate
local valid_altitude_exists = false -- true if there is any valid altitude estimate

-- --------------------------------------------------
-- state flags

local launchpad_position_calibrate_en = false -- set true when the rocket is ready to calibrate the launchpad altitude
local manual_retainer_control = false -- flag to enable manual retainer override 

-- --------------------------------------------------
-- initialization code

-- initialize the running altitude sample array
for i=0, baro_running_alt_n_samples do
    baro_ringbuff_arr[i] = 0
end

-- --------------------------------------------------
-- barometer filtering functions

function process_running_alt (alt_var)

    baro_alt_asl = 0

    baro_ringbuff_arr[baro_ringbuff_idx] = alt_var
    baro_ringbuff_idx = baro_ringbuff_idx + 1

    if baro_ringbuff_idx > baro_running_alt_n_samples then
        baro_initial_average_lock = true
        baro_ringbuff_idx = 1
    end

    for i=0, baro_running_alt_n_samples do
        baro_alt_asl = baro_alt_asl + baro_ringbuff_arr[i]
    end

    baro_alt_asl = baro_alt_asl / baro_running_alt_n_samples

end

-- --------------------------------------------------
-- main loop code

function update ()

    -- --------------------------------------------------
    -- flags and constants

    local vehicle_is_armed = arming:is_armed()

    local manual_retainer_control = false
    local pad_level_en = false

    -- servo IDs
    local payload_deployment_servo_id = SRV_Channels:find_channel(96)
    local nosecone_deployment_servo_id = SRV_Channels:find_channel(97)
    -- local led_servo_id = SRV_Channels:find_channel(98)

    -- RF signals

    -- pad level switch
    if rc:get_pwm(13) > 1500 then
        pad_level_en = true
    else
        pad_level_en = false
    end

    -- manual servo control switch
    if rc:get_pwm(9) > 1500 then
        manual_retainer_control = true
    else
        manual_retainer_control = false
    end

    -- LED control switch
    -- We don't have the hardware functionality for this yet, so i'm leaving this commented out

    -- led_pwm_val = 0
    -- if rc:get_pwm(11) > 1500 then
    --     led_pwm_val = 10000
    -- end
    -- SRV_channels:set_output_pwm_chan(led_servo_id, led_pwm_val)

    -- --------------------------------------------------
    -- altitude calculation and filtering

    local baro_pres = baro:get_pressure()
    local baro_alt_raw = 44330.0 * (1.0 - ((baro_pres/101325.0)^(1.0/5.225)))
    process_running_alt(baro_alt_raw)

    local position_ekf_raw = ahrs:get_position()

    if position_ekf_raw then

        ostr = "distance to launchpad: " .. position_ekf_raw:distance(position_target_landing)
        gcs:send_text(1, ostr)
        
    end

    -- update home position
    if ahrs:home_is_set() then
        local homepos = ahrs:get_home()

        homepos:lat(position_target_landing:lat())
        homepos:lng(position_target_landing:lng())
        
        if ahrs:set_home(homepos) then
            -- gcs:send_text(0, "target location set")
        else
            gcs:send_text(0, "set target location failed")
        end

    end

    -- filtering for the initial launchpad position
    if position_ekf_raw then
    
        ekf_estimate_valid = true

        if pad_level_en and not launchpad_initial_position_lock then
            gcs:send_text(1, "averaging launchpad positon")
            altitude_launchpad_tmp = altitude_launchpad_tmp + (position_ekf_raw:alt() / 100.0)
            position_launchpad_sample_num = position_launchpad_sample_num + 1

            if position_launchpad_sample_num >= position_launchpad_n_samples then
                altitude_launchpad = altitude_launchpad_tmp / position_launchpad_sample_num
                -- position_target_landing:alt(altitude_launchpad*100)
                launchpad_initial_position_lock = true
                gcs:send_text(0, "launchpad initial position lock")
            end

        end 

    else 
        ekf_estimate_valid = false
    end

    if launchpad_initial_position_lock and baro_initial_average_lock and not baro_initial_offset_lock then

        baro_alt_offset_tmp = baro_alt_offset_tmp + (baro_alt_asl - altitude_launchpad)
        baro_offset_alt_sample_num = baro_offset_alt_sample_num + 1

        if baro_offset_alt_sample_num >= baro_offset_alt_n_samples then
            gcs:send_text(0, "baro offset lock")
            baro_alt_offset = baro_alt_offset_tmp / baro_offset_alt_sample_num
            baro_initial_offset_lock = true
        end

    end

    -- chose the best available altitude estimate
    if ekf_estimate_valid and launchpad_initial_position_lock then
        ekf_alt_agl = (position_ekf_raw:alt() / 100.0) - altitude_launchpad
        alt_agl = ekf_alt_agl
        valid_altitude_exists = true
    else 
        if baro_initial_average_lock and baro_initial_offset_lock then
            baro_alt_agl = baro_alt_asl - baro_alt_offset
            alt_agl = baro_alt_agl
            valid_altitude_exists = true
        else
            valid_altitude_exists = false
        end
    end

    -- --------------------------------------------------
    -- deployment / control logic

    if not valid_altitude_exists then
        -- gcs:send_text(0, "NO VALID ALTITUDE READING")
    else
        local ostr = "alt AGL ("
        if ekf_estimate_valid then
            ostr = ostr .. "g): "
        else
            ostr = ostr .. "b): "
        end
        ostr = ostr .. tostring(alt_agl * 3.28084)
        gcs:send_text(1, ostr)
    end 


    if vehicle_is_armed and valid_altitude_exists then
        
        local alt_agl_ft = alt_agl * 3.28084
    
        if not manual_retainer_control then

            if alt_agl_ft <= deployment_altitude_nosecone_ft then

                if millis() > servo_last_wiggle_time_nosecone_ms + servo_wiggle_delay_ms and alt_agl_ft >= deployment_floor_nosecone_ft then

                    if servo_angle_nosecone_cur == servo_stowed_value_nosecone then
                        servo_angle_nosecone_cur = servo_deployed_value_nosecone
                    else
                        servo_angle_nosecone_cur = servo_stowed_value_nosecone
                    end
                
                    servo_last_wiggle_time_nosecone_ms = millis()

                    gcs:send_text(1, "wiggling nosecone servo")

                end

                if alt_agl_ft <= deployment_floor_nosecone_ft then                

                    servo_angle_nosecone_cur = servo_stowed_value_nosecone

                end

            end

            if alt_agl_ft <= deployment_altitude_payload_ft then

                if millis() > servo_last_wiggle_time_payload_ms + servo_wiggle_delay_ms and alt_agl_ft >= deployment_floor_payload_ft then

                    if servo_angle_payload_cur == servo_stowed_value_payload then
                        servo_angle_payload_cur = servo_deployed_value_payload
                    else
                        servo_angle_payload_cur = servo_stowed_value_payload
                    end
                
                    servo_last_wiggle_time_payload_ms = millis()

                    gcs:send_text(1, "wiggling payload servo")

                end

                if alt_agl_ft <= deployment_floor_payload_ft then                

                    servo_angle_payload_cur = servo_stowed_value_payload

                end

            end
        
        end

    end

    -- manual control override
    if manual_retainer_control then
        servo_angle_nosecone_cur = rc:get_pwm(6)
        servo_angle_payload_cur = rc:get_pwm(8)
    end

    -- update servo positions
    SRV_Channels:set_output_pwm_chan(nosecone_deployment_servo_id, servo_angle_nosecone_cur)
    SRV_Channels:set_output_pwm_chan(payload_deployment_servo_id, servo_angle_payload_cur)

    -- local ostr = "nosecone: " .. tostring(servo_angle_nosecone_cur)
    -- gcs:send_text(1, ostr)
    -- ostr = "payload: " .. tostring(servo_angle_payload_cur)
    -- gcs:send_text(1, ostr)


    -- run again in 50ms (20Hz loop)
    return update, 50
end

return update, 1000 -- run update 1 second after boot
