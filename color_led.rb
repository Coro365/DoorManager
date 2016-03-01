require 'wiringpi2'

RED_LED_PIN = 8		#gpio2
GRE_LED_PIN = 9		#gpio3
BLU_LED_PIN = 15	#gpio14

LED = WiringPi::GPIO.new do |gpio|
	gpio.pin_mode(RED_LED_PIN, WiringPi::OUTPUT)
	gpio.pin_mode(BLU_LED_PIN, WiringPi::OUTPUT)
	gpio.pin_mode(GRE_LED_PIN, WiringPi::OUTPUT)
end

def init_p
	all(0)
	all(1)
end

def wait_p
	cyan(1)
end

def nfc_wait_p
	sleep(2)
	all(0)
	cyan(1)
end

def auto_lock_p
	loop do
		magenta(1)
	end
end

def auto_lock_wait_p
	loop do
		magenta(1)
		sleep(1)
		magenta(0)
		sleep(1)
	end
end

def open_p
	loop do
		yellow(1)
		sleep(1)
		yellow(0)
		sleep(1)
	end
end

def lock_p
	blue(1)
end

def unlock_p
	red(1)
end

def error_p
	loop do
		red(1)
		sleep(1)
		red(0)
		sleep(0.5)
	end
end

def illegal_p
	10.times do
		red(1)
		sleep(0.1)
		red(0)
		sleep(0.1)
	end
end


def red(use)
	LED.digital_write(RED_LED_PIN, WiringPi::LOW) if use == 1
	LED.digital_write(RED_LED_PIN, WiringPi::HIGH) if use == 0
end

def blue(use)
	LED.digital_write(BLU_LED_PIN, WiringPi::LOW) if use == 1
	LED.digital_write(BLU_LED_PIN, WiringPi::HIGH) if use == 0
end

def green(use)
	LED.digital_write(GRE_LED_PIN, WiringPi::LOW) if use == 1
	LED.digital_write(GRE_LED_PIN, WiringPi::HIGH) if use == 0
end

def yellow(use)
	green(use)
	red(use)
end

def magenta(use)
	red(use)
	blue(use)
end

def cyan(use)
	blue(use)
	green(use)
end

def all(use)
	[RED_LED_PIN, BLU_LED_PIN, GRE_LED_PIN].each do |pin|
		LED.digital_write(pin, WiringPi::LOW) if use == 1
		LED.digital_write(pin, WiringPi::HIGH) if use == 0
	end
end

def led_test
	p "clear"
	all(0)

	p "red"
	red(1)
	sleep(3)
	red(0)
	sleep(3)

	p "blue"
	blue(1)
	sleep(3)
	blue(0)

	p "green"
	green(1)
	sleep(3)
	green(0)

	p "magenta"
	magenta(1)
	sleep(3)
	magenta(0)

	p "cyan"
	cyan(1)
	sleep(3)
	cyan(0)

	p "yellow"
	yellow(1)
	sleep(3)
	yellow(0)

	p "all"
	all(1)
	sleep(3)
	all(0)
	sleep(3)

end
