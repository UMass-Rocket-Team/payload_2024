function update ()

  if is_armed() then
  local servo1 = 96
  local servo2 = 97
  local servo_pos_1 = 1000
  local servo_pos_2 = 2000
  local deploy_channel = 11
  local deploy_channel_threshold = 1200 -- A value lower than 1200 will be considered "safe to deploy"



  local current_pos = ahrs:get_position()
  local home = ahrs:get_home()
  if current_pos and home then
    local altitude = current_pos:alt(home)

    -- case 1: over 500 ft, remain idle, keep nosecone and payload in bay
    if alt > 500 then

      servo.set_output_pwm(servo1, servo_pos_1)
      servo.set_output_pwm(servo2, servo_pos_1)


    -- case 2: over 400 ft, deploy the nosecone but keep payload stowed
    elseif alt > 400 then

      servo.set_output_pwm(servo1, servo_pos_1)
      servo.set_output_pwm(servo2, servo_pos_2)


    -- case 3: unlock the payload, if deployment is allowed
    else

      if get_pwm(deploy_channel) < deploy_channel_threshold then

      servo.set_output_pwm(servo1, servo_pos_2)
      servo.set_output_pwm(servo2, servo_pos_2)




    end
  end

  return update, 250
end
return update, 1000

end
end
