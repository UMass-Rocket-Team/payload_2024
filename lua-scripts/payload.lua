------- User Editable Global Variables -------
local FREQUENCY = 250
local PAYLOAD_RETENTION_SERVO = 96
local CONE_RETENTION_SERVO = 97
local payload_servo_channel = SRV_Channels:find_channel(PAYLOAD_RETENTION_SERVO)
local cone_servo_channel = SRV_Channels:find_channel(CONE_RETENTION_SERVO)
--Servo Positions---
local LOCKED_PAYLOAD_SERVO_POS = 1000
local UNLOCKED_PAYLOAD_SERVO_POS = 2000
local LOCKED_CONE_SERVO_POS = 1000
local UNLOCKED_CONE_SERVO_POS = 2000

local DEPLOY_CHANNEL_THRESHOLD = 1200 -- A value lower than 1200 will be considered "safe to deploy"
local MAX_NOSECONE_DEPLOYMENT_ALT = 500
local MIN_NOSECONE_DEPLOYMENT_ALT = 400
local MODES = {["STABILIZE"] = 0, ["ALT_HOLD"] = 2, ["RTL"] = 6}

--Decorator to pass standardized data
function standard_data_collection(f)
  return function(self)
    local altitude = alt()
    gcs:send_text(0, "Altitude: " .. altitude)
    return f(self, altitude)
  end
end

function startup()
  -- Zero altitude (REMOVE IF THIS SCRIPT IS NOT STARTED ON LAUNCH)
  alt(0)
  vehicle:set_mode(MODES["STABILIZE"])
  return standard_data_collection(idle(self, altitude)) FREQUENCY
end

function idle(altitude)
  local altitude = alt()
  gcs:send_text(0, "State: IDLE. Awaiting Arming")
  gcs:send_text(0, "Altitude: " .. altitude)
  -- Confirm that retention is set
  SRV_Channels:set_output_pwm(payload_servo_channel, LOCKED_PAYLOAD_SERVO_POS)
  SRV_Channels:set_output_pwm(cone_servo_channel, LOCKED_CONE_SERVO_POS)
  -- Check for manual arming
  arming:is_armed() then
    return standard_data_collection(check_deploy_cone(self, altitude)), FREQUENCY
  end
  -- This was here, but seems like it is unused?
  -- if rc:get_pwm(11) < DEPLOY_CHANNEL_THRESHOLD then
  --   return check_deploy_cone FREQUENCY
  -- end
end

-- Function: check_deploy_cone
-- Description: Checks the altitude of the current position and deploys the payload cone if the altitude is within the specified range.
-- Returns: Changes to state deploy_payload if the altitude is within the specified range, otherwise returns to check_deploy_cone
function check_deploy_cone(altitude)
  gcs:send_text(0, "State: CONE DEPLOYMENT. Checking for deployment altitude [min:" .. MIN_NOSECONE_DEPLOYMENT_ALT .. ", max:" .. MAX_NOSECONE_DEPLOYMENT_ALT .. "]")
  gcs:send_text(0, "Altitude: " .. altitude)
  if MAX_NOSECONE_DEPLOYMENT_ALT > altitude > MIN_NOSECONE_DEPLOYMENT_ALT then
    gcs:send_text(0, "Deploying nosecone...")
    SRV_Channels:set_output_pwm(payload_servo_channel, LOCKED_PAYLOAD_SERVO_POS) --redundant
    SRV_Channels:set_output_pwm(cone_servo_channel, UNLOCKED_CONE_SERVO_POS)
    return standard_data_collection(deploy_payload(self, altitude)), FREQUENCY
  end

  return standard_data_collection(check_deploy_cone(self, altidtude)), FREQUENCY
end

-- Function: deploy_payload
-- Description: Deploys the payload by unlocking the retention servos and then arming and stabilizing the system.
-- Returns: Changes state to arm_drone.
function deploy_payload()
  gcs:send_text(0, "State: PAYLOAD DEPLOYMENT. Deploying payload...")
  SRV_Channels:set_output_pwm(payload_servo_channel, UNLOCKED_PAYLOAD_SERVO_POS)
  SRV_Channels:set_output_pwm(cone_servo_channel, UNLOCKED_CONE_SERVO_POS) --redundant
  --NEED TO SEE HOW LONG WE NEED TO WAIT BEFORE VEHICLE LEAVES PAYLOAD, and if we need to check for any params
  return standard_data_collection(check_deploy_cone(self, alt)) FREQUENCY
end

function await_altitude_hold()
  gcs:send_text(0, "State: AWAITING ALTITUDE HOLD. Awaiting manual transition to ALT_HOLD")
  if vehicle:get_mode() == MODES["ALT_HOLD"]
    complete()
  end
  await_altitude_hold()
end

function complete()
  gcs:send_text(0, "AUTONOMOUS CONTROL COMPLETE. MANUAL CONTROL ")
end

-- Start the script in the idle state
return startup, FREQUENCY
