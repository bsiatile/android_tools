#!/usr/bin/ruby

if ARGV.length != 1 || !"#{ARGV[0]}".include?(".apk")
  puts "Command expects the APK as an argument"
end

aaptInfo = `aapt dump badging \"#{ARGV[0]}\"`
firstLine = aaptInfo.split("\n")[0]
packageName = firstLine.slice(/\'([^"]*)\'/).split(' ')[0]

puts packageName.tr("'", "")
