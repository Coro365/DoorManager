require 'wiringpi2'
require 'fileutils'
require './config.rb'
require './color_led.rb'

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

def door_state_change_open?
	#状態が変わったとき真を返す
	past_state = door_open?
	loop do
		state = door_open?

		unless state == past_state
			if state == true
				puts "close => open"
				return true
			else
				puts "opne => close"
				return false
			end
		end

		past_state = state
		sleep(1)
	end
end

def door_open?
	io = WiringPi::GPIO.new
	io.pin_mode(READ_SW_PIN, WiringPi::INPUT)

	return true if io.digital_read(READ_SW_PIN) == 0
	return false if io.digital_read(READ_SW_PIN) == 1
	return nil

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
	else
		action_id = "0"
		action = "error"
	end

	# send influxdb
	system("curl -i -XPOST '#{INFLUXDB}' --data-binary 'doorkey,location=4,user=#{user},idm=#{idm},action=#{action} value=#{action_id}'")
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

def auto_lock()
	indicator("auto_lock")

	print("Unlocking...\n")
	unlock_servo

	until door_state_change_open? ; end	#open
	indicator("open")
	while door_state_change_open? ;	end	#close

	indicator("auto_lock_wait")
	sleep AUTO_LOCK_SEC

	print("Locking...\n")
	lock_servo
	indicator("wait")
end

def lock
	indicator("lock")
	log("button", "lock")
	print("Locking...")

	lock_servo
	sleep(BUTTON_WAIT_SEC)
	print("\tDone\n")
	indicator("wait")
end

def unlock
	indicator("unlock")
	log("button", "unlock")
	print("Unlocking...")

	unlock_servo
	sleep(BUTTON_WAIT_SEC)
	print("\tDone\n")
	indicator("wait")
end

def button
	io = WiringPi::GPIO.new do |gpio|
		gpio.pin_mode(LOCK_BUTTON_PIN, WiringPi::INPUT)
		gpio.pin_mode(UNLOCK_BUTTON_PIN, WiringPi::INPUT)
	end

	button = Thread.new do
		print("Start monitoring button\n")
		loop do
			lock if io.digital_read(LOCK_BUTTON_PIN) == 1
			unlock if io.digital_read(UNLOCK_BUTTON_PIN) == 1
			sleep(0.1)
		end
	end
end

def touch
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

def file_monitor
  flag_files = Hash.new
  flag_files[:auto] = File.expand_path("./auto_flagfile")
  flag_files[:lock] = File.expand_path("./lock_flagfile")
  flag_files[:unlock] = File.expand_path("./unlock_flagfile")

  file_monitor = Thread.new do
	  loop do
	    flag_files.each do |flag, path|

	      if File.exist?(path)
	        p "exist #{flag}"
	        auto_lock if flag == :auto
	        lock if flag == :lock
	        unlock if flag == :unlock
	        FileUtils.rm(path)
	      else
	        p "not exist #{flag}"
	      end
	    end
	    sleep(0.5)
	  end
	end
end

indicator("init")
sleep(1)
log("door_manager", "START")

button
file_monitor
touch
