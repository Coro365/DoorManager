# README
This programs can home door key control from nfc card.

check my [blog](http://coro.hatenadiary.jp/entry/2015/12/23/233434)

## Using

###nfcpy
```
sudo apt-get install bzr
cd <hoge>
bzr branch lp:nfcpy trunk

sudo apt-get install python-usb
```

### ServoBlaster
```
git clone git://github.com/richardghirst/PiBits.git
cd PiBits/ServoBlaster/user
make
sudo make install
```

### wiringpi2
```
git clone git://git.drogon.net/wiringPi
cd wiringPi
./build

apt-get install ruby-dev
gem install wiringpi2
```
