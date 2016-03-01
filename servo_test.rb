
#s03t-2bbmg servo
UNLOCK_ANGLE = "92"
LOCK_ANGLE = "46"

#zs-f135 servo
#UNLOCK_ANGLE = "57"
#LOCK_ANGLE = "12"

req = ARGV[0]

def unlock()
	print("Unlocking...\n")
	`echo 4=#{UNLOCK_ANGLE}% > /dev/servoblaster`
end

def lock()
	print("Locking...\n")
	`echo 4=#{LOCK_ANGLE}% > /dev/servoblaster`
end

if req == "lock" || req == "l"
	lock
elsif req == "unlock" || req == "u"
	unlock
else 
	lock
	sleep(4)
	unlock
	sleep(4)
end
