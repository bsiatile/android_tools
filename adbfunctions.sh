#!/bin/sh

DEFAULT_USERNAME=`whoami`

# To perform adb command on all devices, make
# sure the environment variable "MULTI" is set
adb_wrapper() {
  if [ "${MULTI}" != "" ]; then
    adb devices | egrep '\t(device|emulator)' | cut -f 1 | xargs -J% -n1 -P5 \
          adb -s % "$@"
  else
    adb $@
  fi
}

adbclear() {
  adb shell pm clear $1
}

adbdevices() {
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  ruby -I $DIR -e "
    require \"android_devices\"

    android_device = AndroidDevices.new
    serial_list = android_device.get_serial_list
    serial_list.each_with_index do |serial, index|
      model = \`adb -s #{serial} shell getprop | grep model\`
            .split(/.*: /)[1]
            .chomp
            .gsub(/[\[\]]/, \"\")

      list = \"#{index}) #{model} - #{serial}\"
      if ENV[\"ANDROID_SERIAL\"] == serial
        list << \"   <= current\"
      end

      puts list
    end

    if serial_list.length <= 1
      exit 0
    else
      print \"Enter a number if you want to set one of the above serial numbers: \"
      exit gets.to_i
    end
  "

  num=$?
  serial=$(ruby -I $DIR -e "
    require \"android_devices\"

    android_device = AndroidDevices.new
    puts android_device.get_serial_at_index(ARGV[0])
  " ${num})

  if [ "$serial" != "" ]; then
    echo "Setting ANDROID_SERIAL to $serial"
    export ANDROID_SERIAL=$serial
  else
    echo "Invalid option. $num will return serial: $serial"
    echo "Leaving ANDROID_SERIAL alone"
  fi
}

adbenter() {
  ensure_adb_serial_set
  adb_wrapper shell input keyevent KEYCODE_ENTER
}

adbhelp() {
  echo "adbclear - Given a package name, will clear the sandbox for the application. Usage: adbclear pkg_name"
  echo "adbdevices - Returns a list of devices currently connected to the computer"
  echo "adbenter - Simulates a tap on the current widget"
  echo "adbpass - Allows typing of secure password. Usage: adbpass"
  echo "adbpointer - toggles pointer location overlay. 0 will disable it, any other number will enable it. Usage: adbpointer 0"
  echo "adbscreenshot - Takes a screenshot of device and saves in current dir. Usage: adbscreenshot filename"
  echo "adbtab - Goes to the next widget"
  echo "adbtype - Types in the text provided. Usage: adbtype sample"
  echo "getpackagename - Returns package name of apk. Usage: getpackagename foo.apk"
}

adbpass() {
  ensure_adb_serial_set

  if [ "${1}" == "" ]; then
    echo "Please enter your password: "
    read -s password
  else
    password=${1}
  fi

  checkIfMissingArgument $password
  if [ $? -eq 0 ]; then
    adbtype \'$password\'
  fi
}

adbpointer() {
  ensure_adb_serial_set
  checkIfMissingArgument $1

  if [ $? -eq 0 ]; then
    if [ "$1" -eq "0" ]; then
      adb shell settings put system pointer_location 0
    else
      adb shell settings put system pointer_location 1
    fi
  fi
}

adbscreenshot() {
  ensure_adb_serial_set
  checkIfMissingArgument $1

  if [ $? -eq 0 ]; then
    adb_wrapper shell screencap -p /sdcard/${1}.png
    adb_wrapper pull /sdcard/${1}.png .
    adb_wrapper shell rm /sdcard/${1}.png
  fi
}

adbtab() {
  ensure_adb_serial_set
  adb_wrapper shell input keyevent KEYCODE_TAB
}

adbtype() {
  ensure_adb_serial_set
  checkIfMissingArgument $1

  if [ $? -eq 0 ]; then
    adb_wrapper shell input text $1
  fi
}

checkIfMissingArgument() {
  if [ "$1" == "" ]; then
    echo "Must provide input string to type."
    echo "Please call 'adbhelp' to see usage for relevant command"
    return 1;
  fi

  return 0;
}

ensure_adb_serial_set() {
  if [ "$MULTI" == "" ]; then
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    ruby -I $DIR -e "
      require \"android_devices\"
   
      android_device = AndroidDevices.new
      android_device.exit_if_android_serial_env_invalid
    "
   
    if [ $? -ne 0 ]; then
      adbdevices
    fi
  fi
}

getpackagename() {
  package=$(ruby -e "
    if ARGV.length != 1 || !ARGV[0].include?(\".apk\")
      puts \"Command expects the APK as an argument\"
      exit
    else
      aaptInfo = \`aapt dump badging #{ARGV[0]}\`
      firstLine = aaptInfo.split(\"\n\")[0]
      packageName = firstLine.slice(/\'([^\"]*)\'/).split(' ')[0]

      puts packageName.gsub(\"'\", \"\")
    end
    " "$1")

    echo $package
}

function adblogcat()
{
    ANDROID_DEVICE=$1
    LOGFILE1=xxx
    LOGFILE2=$(date "+logcat-%Y.%m.%d-%H.%M.%S_${ANDROID_SERIAL}.log")

    echo Clearing logs...
    adb $ANDROID_DEVICE  logcat -c
    echo Logcat to file [$LOGFILE1] and [$LOGFILE2]
    adb $ANDROID_DEVICE logcat -v threadtime | tee $LOGFILE1 | tee $LOGFILE2
}

# Uninstall and install an apk given an apk file
function adbreinst()
{
    apkfile=$1
    pkg=`getpackagename "$apkfile"`

    echo "Uninstalling $pkg"
    adb uninstall $pkg
    echo "Waiting for things to cool down..."
    sleep 2
    echo "Installing..."

    adb install "$apkfile"
}

export -f adbclear
export -f adbdevices
export -f adbenter
export -f adbpass
export -f adbpointer
export -f adbscreenshot
export -f adbtab
export -f adbtype
export -f getpackagename
export -f adblogcat
export -f adbreinst
export -f checkIfMissingArgument
export -f ensure_adb_serial_set
export -f adb_wrapper

alias madb="MULTI=1 adb_wrapper"
