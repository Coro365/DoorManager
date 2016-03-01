require 'wiringpi2'
require './config.rb'
require './color_led.rb'


def screen_sleep(n)
	n.downto(1) do |i|
		show = "#{i}sec..."
		print(show)
		sleep(1)
		a = show.size
		print("\e[#{a}D")
	end
end

def nfc()
	`sudo python /home/pi/Documents/nfc/trunk/examples/tagtool.py`
end

def idm(text)
	m = text.match(/ID=(.*?)\s/)
	idm =m[1]
	return idm
end

def unlock()
	`echo #{SERVO_PIN}=#{UNLOCK_ANGLE}% > /dev/servoblaster`
end

def lock()
	`echo #{SERVO_PIN}=#{LOCK_ANGLE}% > /dev/servoblaster`
end

def door_state_change_open?
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

	if io.digital_read(READ_SW_PIN) == 0
		#print("Door state open\n")
		return true
	elsif io.digital_read(READ_SW_PIN) == 1
		#print("Door state close\n")
		return false
	else
		print("Door state unknown\n")
		return nil
	end

end

def log(user, operation)
	File.open("log.txt","a") do |f|
		f.print("#{Time.now},#{user},#{operation}\n")
	end
	print("\n#{Time.now},#{user},#{operation}\n")
end

def indicator(pattern)
	#puts ("(indicator #{pattern})")

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
	unlock

	until door_state_change_open? ; end	#open
	indicator("open")
	while door_state_change_open? ;	end	#close

	indicator("auto_lock_wait")
	screen_sleep(AUTO_LOCK_SEC)

	print("Locking...\n")
	lock
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

			if io.digital_read(LOCK_BUTTON_PIN) == 1
				
				indicator("lock")
				log("button", "lock")
				print("Locking...")

				lock
				sleep(BUTTON_WAIT_SEC)
				print("\tDone\n")
				indicator("wait")
			end

			if io.digital_read(UNLOCK_BUTTON_PIN) == 1
				
				indicator("unlock")
				log("button", "unlock")
				print("Unlocking...")

				unlock
				sleep(BUTTON_WAIT_SEC)
				print("\tDone\n")
				indicator("wait")
			end
			sleep(0.1)
		end
	end
end

def touch()
	loop do
		indicator("nfc_wait")

		begin
			idm = idm(nfc)
		rescue Exception => e
			log("door_manager", "ERROR: Unknow #{e.message}")
			print("Unknow ERROR!\n")
			indicator("error")
			sleep(10)
			all(0)
			exit(3)
		end
		unlock_user = USERS.key(idm)

		unless unlock_user == nil
			log(unlock_user, "auto")
			print("Welcome back #{unlock_user}!\n")
			auto_lock
		else
			log(idm, "No authority")
			indicator("illegal")
			print("Illegal user (#{idm})\n")
			sleep(2)
		end
		print("Done\n\n")
		print("Please wait reader restrat...\n")
	end
end

indicator("init"); sleep(1)
log("door_manager", "START")

button
touch
