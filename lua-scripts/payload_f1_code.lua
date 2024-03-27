-- 1000ft AGL drone is armed
-- 700ft main chute comes out
-- 600 or 650ft nosecone deploys
-- 500ft payload deploys

-- TODO:
-- test that the deployment actually works for nosecone vs payload
-- get correct servo values for nosecone and payload positions
-- get the correct channels for nosecone vs payload

-- radio channel 6 IS NOSECONE
-- radio channel 8 IS PAYLOAD

local starting_alt
local starting_alt_tmp = 0

local manual_retainer_control = false

-- starting altitude filtering data
local starting_alt_sample_num = 0
local starting_alt_n_samples = 100

-- running altitude filtering data
local running_alt_arr = {}
local running_alt_arr_idx = 1
local running_alt_n_samples = 20

local baro_alt_initial_avg_lock = false

-- initialize the running altitude sample array
for i=0, running_alt_n_samples do
    running_alt_arr[i] = 0
end

function process_starting_alt (alt_var)

    if starting_alt_sample_num >= starting_alt_n_samples then
        return true
    end

    starting_alt_tmp = starting_alt_tmp + alt_var
    starting_alt_sample_num = starting_alt_sample_num + 1

    if starting_alt_sample_num >= starting_alt_n_samples then

        starting_alt_tmp = starting_alt_tmp / starting_alt_sample_num
        return true

    end

    return false

end

function process_running_alt (alt_var)

    local ret = 0

    running_alt_arr[running_alt_arr_idx] = alt_var
    running_alt_arr_idx = running_alt_arr_idx + 1

    if running_alt_arr_idx > running_alt_n_samples then
        baro_alt_initial_avg_lock = true
        running_alt_arr_idx = 1
    end

    for i=0, running_alt_n_samples do
        ret = ret + running_alt_arr[i]
    end

    ret = ret / running_alt_n_samples

    return ret

end

-- MUST CHANGE BEFORE FLIGHT
local nosecone_deployment_altitude_ft = 600.0
local payload_deployment_altitude_ft = 500.0

-- dummy values
local nosecone_deployed_servo_angle = 2000
local nosecone_stowed_servo_angle = 1000

-- dummy values
local payload_deployed_servo_angle = 1000
local payload_stowed_servo_angle = 2000

local meters_to_ft = 3.28084

-- flags
local payload_has_deployed = false
local nosecone_has_deployed = false

function update () -- periodic function that will be called
    
	local vehicle_is_armed = arming:is_armed()

    if rc:get_pwm(9) > 1500 then
        manual_retainer_control = true
    else
        manual_retainer_control = false
    end
       
    -- servo IDs
    local payload_deployment_servo_id = SRV_Channels:find_channel(96)
    local nosecone_deployment_servo_id = SRV_Channels:find_channel(97)

	-- baro_alt

    local baro_alt
	local baro_alt_raw
	local baro_pres = baro:get_pressure()

	if baro_pres then

        baro_alt_raw = 44330.0 * (1.0 - ((baro_pres/101325.0)^(1.0/5.225)))
        baro_alt = process_running_alt(baro_alt_raw)
        
        if not baro_alt_initial_avg_lock then
            gcs:send_text(5, "waiting for initial baro lock")
        else

            if not starting_alt then    
                gcs:send_text(5, "calibrating starting altitude")
                if process_starting_alt(baro_alt) then
                    gcs:send_text(2, "starting alt calibrated")
                    starting_alt = starting_alt_tmp
                end
            else

                baro_alt = baro_alt - starting_alt

                -- altitude data
                local altitude_ft = baro_alt * meters_to_ft

                -- print altitude, remove before flight
                -- local ostr = "altitude_ft = "
                -- ostr = ostr .. tostring(altitude_ft)
                -- gcs:send_text(2, ostr)

                if vehicle_is_armed then

                    -- nosecone deployment
                    if altitude_ft < nosecone_deployment_altitude_ft then
                        if not manual_retainer_control then
                            SRV_Channels:set_output_pwm_chan(nosecone_deployment_servo_id, nosecone_deployed_servo_angle)
                        end

                        -- debugging text
                        if not nosecone_has_deployed then
                            gcs:send_text(0, "Initiating nosecone deployment")
                            nosecone_has_deployed = true
                        end

                    else
                        -- removing this for flight
                        -- if not manual_retainer_control then
                        --     SRV_Channels:set_output_pwm_chan(nosecone_deployment_servo_id, nosecone_stowed_servo_angle)
                        -- end
                    end

                    -- payload deployment
                    if altitude_ft < payload_deployment_altitude_ft then
                        if not manual_retainer_control then
                            SRV_Channels:set_output_pwm_chan(payload_deployment_servo_id, payload_deployed_servo_angle)
                        end 

                        -- debugging text
                        if not payload_has_deployed then
                            gcs:send_text(0, "Initiating payload deployment")
                            payload_has_deployed = true
                        end

                    else
                        -- removing this for flight
                        -- if not manual_retainer_control then
                        --     SRV_Channels:set_output_pwm_chan(payload_deployment_servo_id, payload_stowed_servo_angle)
                        -- end
                    end

                end

            end
        end
	else
		gcs:send_text(0, "no baro data")
	end

	if manual_retainer_control then
        SRV_Channels:set_output_pwm_chan(nosecone_deployment_servo_id, rc:get_pwm(6))
		SRV_Channels:set_output_pwm_chan(payload_deployment_servo_id, rc:get_pwm(8))
    end

	-- request "update" to be rerun again 10 milliseconds (0.1 second) from now
    -- at 20Hz refresh rate, this code will run ~ every 1.5ft during descent
    return update, 50
end

return update, 1000 -- request "update" to be the first time 10 milliseconds (0.1 second) after script is loaded
