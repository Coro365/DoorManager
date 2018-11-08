require 'wiringpi2'
require 'fileutils'
require './config.rb'
require './color_led.rb'


###########################
#   Basic

def get_idm
  result = `sudo python /home/pi/Documents/nfc/trunk/examples/tagtool.py`
  m = result.match(/ID=(.*?)\s/)
  idm = m[1]
  return idm
end

def unlock_servo
  `echo #{SERVO_PIN}=#{UNLOCK_ANGLE}% > /dev/servoblaster`
end

def lock_servo
  `echo #{SERVO_PIN}=#{LOCK_ANGLE}% > /dev/servoblaster`
end

def influx_post(door_percent)
  puts "ocaction,location=4 value=#{door_percent}"
  system("curl -i -XPOST '#{INFLUXDB}' --data-binary 'ocaction,location=4 value=#{door_percent}' >/dev/null 2>&1")
end

def log(user, action,idm="0")
  print("\n#{Time.now},#{user},#{action}\n")

  # create log.txt
  File.open("log.txt","a") do |f|
    f.print("#{Time.now},#{user},#{action}\n")
  end

  case action
  when "auto" then
    action_id = "1"
  when "lock" then
    action_id = "2"
  when "unlock" then
    action_id = "3"
  when "unknow_card" then
    action_id = "4"
  when "START" then
    action_id = "5"
  else
    action_id = "0"
    action = "error"
  end

  # send influxdb
  puts "doorkey,location=4,user=#{user},idm=#{idm},action=#{action} value=#{action_id}"
  system("curl -i -XPOST '#{INFLUXDB}' --data-binary 'doorkey,location=4,user=#{user},idm=#{idm},action=#{action} value=#{action_id}' >/dev/null 2>&1")
end

def indicator(pattern)

  Thread.kill($led_th) unless pattern == "init"
  all(0) unless pattern == "nfc_wait"

  $led_th = Thread.new do
    init_p if pattern == "init"
    wait_p if pattern == "wait"
    auto_lock_wait_p if pattern == "auto_lock_wait"
    auto_lock_p if pattern == "auto_lock"
    open_p if pattern == "open"
    lock_p if pattern == "lock"
    unlock_p if pattern == "unlock"
    nfc_wait_p if pattern == "nfc_wait"
    error_p if pattern == "error"
    illegal_p if pattern == "illegal"
  end
end



#################################
#   Logic

def auto_lock()

  indicator("auto_lock")

  print("Unlocking...\n")
  unlock_servo

  until door_state_change? ; end  #open
  indicator("open")
  while door_state_change? ;  end #close

  indicator("auto_lock_wait")
  sleep AUTO_LOCK_SEC

  print("Locking...\n")
  lock_servo
  indicator("wait")

end

def lock(user)
  indicator("lock")
  log(user, "lock")
  print("Locking...")

  lock_servo
  sleep(BUTTON_WAIT_SEC)
  print("\tDone\n")
  indicator("wait")
end

def unlock(user)
  indicator("unlock")
  log(user, "unlock")
  print("Unlocking...")

  unlock_servo
  sleep(BUTTON_WAIT_SEC)
  print("\tDone\n")
  indicator("wait")
end

########################################3
#   Sensor

def door_state_change?
  past = $door_state
  loop do 
    return $door_state unless past == $door_state
  end

end

def door_monitor

  door_t = Thread.new do
    print("Start monitoring door\n")
    past_state = $door_state
  
    loop do
      # door state change
      unless  past_state == $door_state
        if $door_state == true
          puts "close => open"
          influx_post("100")
        elsif $door_state == false
          puts "opne => close"
          influx_post("0")
        end
      end
      past_state = $door_state
      sleep 0.5
    end

  end
  # wait first io read
  sleep 2
  
end

def io_monitor
  io = WiringPi::GPIO.new do |gpio|
    gpio.pin_mode(LOCK_BUTTON_PIN, WiringPi::INPUT)
    gpio.pin_mode(UNLOCK_BUTTON_PIN, WiringPi::INPUT)
    gpio.pin_mode(READ_SW_PIN, WiringPi::INPUT)
  end

  io_t = Thread.new do
    print("Start monitoring IO\n")
    loop do
      # button 
      lock("button") if io.digital_read(LOCK_BUTTON_PIN) == 1
      unlock("button") if io.digital_read(UNLOCK_BUTTON_PIN) == 1

      # door
      read_sw = io.digital_read(READ_SW_PIN)
      $door_state = true if read_sw == 0
      $door_state = false if read_sw == 1

    end
  end

  # wait first io read
  sleep 2

end

#########################################3
#   Card Reader

def card_monitor
  print("Start monitoring card reader\n")

  loop do
    indicator("nfc_wait")

    begin
      idm = get_idm
    rescue Exception => e
      log("door_manager", "ERROR: NFC Reader not found")
      puts "ERROR: NFC Reader not found"
      indicator("error")
      sleep(10)
      all(0)
      exit(3)
    end
    unlock_user = USERS.key(idm)

    unless unlock_user == nil
      log(unlock_user, "auto",idm)
      print("Welcome back #{unlock_user}!\n")
      auto_lock
    else
      log(idm, "unknow_card",idm)
      indicator("illegal")
      print("Illegal user (#{idm})\n")
      sleep(2)
    end
    print("Done\n\n")
    print("Please wait reader restrat...\n")
  end
end

#########################################3
#   File Flag

def file_monitor
  flag_files = Hash.new
  flag_files[:auto] = File.expand_path("./auto_flagfile")
  flag_files[:lock] = File.expand_path("./lock_flagfile")
  flag_files[:unlock] = File.expand_path("./unlock_flagfile")

  file_monitor = Thread.new do
    print("Start monitoring file\n")

    loop do
      flag_files.each do |flag, path|

        if File.exist?(path)
          p "exist #{flag}"
          auto_lock if flag == :auto
          lock("api") if flag == :lock
          unlock("api") if flag == :unlock
          FileUtils.rm(path)
        else
          #p "not exist #{flag}"
        end
      end
      sleep(0.5)
    end
  end

  # wait first file read
  sleep 2

end



indicator("init")
log("door_manager", "START")
io_monitor
door_monitor
file_monitor
card_monitor
