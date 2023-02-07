class AndroidDevices
  attr_reader :devices

  def initialize
    get_serial_list
  end

  def get_serial_list
    serials = `adb devices`.split("\n").drop(1) #drops the first string in adb devices (which is just text)
    @devices = serials.map { |serial| 
        items = serial.split("\t")
        if items[1] == "offline"  then
            ""
        else
            items[0]
        end
    }

    @devices = @devices.reject { |i| i == "" }
    @devices
  end

  def include?(value)
    @devices.include?(value)
  end

  def get_serial_at_index(index)
    @devices[index.to_i] if index.to_i.to_s == index || index.class == Fixnum
  end

  def exit_if_android_serial_env_invalid
    exit 1 if !get_serial_list.include? ENV['ANDROID_SERIAL']
  end
end
