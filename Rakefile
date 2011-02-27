require 'pathname'

APPNAME = "TextMateVim"
DEV_TEXTMATE = ENV["DevTextMate"] || "/Applications/DevTextMate.app/Contents/MacOS/DevTextMate"
CONFIGURATION = ENV['Configuration'] || 'Debug'

task :default => :test
task :run => :build

task :build do
  # Textmate is currently built against i386, and so must our plugin be.
  sh "xcodebuild -configuration #{CONFIGURATION} ARCHS='i386'"
end

task :run do
  exec "build/Debug/textmatevim.app/Contents/MacOS/textmatevim"
end

task :test do |task|
  Dir.glob("test/*_test.rb").each do |filename|
    sh "ruby #{filename}"
  end
end

# We open this file in textmate to play around with the editing features of our plugin.
SAMPLE_FILE = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n" + "My baloney has a first name, it's HOMER\n" * 20

desc "Launches a development version of textmate, with TextMateVim active"
task :launch => :build
task :launch do
  kill_process(DEV_TEXTMATE)
  output_path = File.expand_path("build/Debug/#{APPNAME}.bundle")

  symlink_target = File.expand_path(
      "~/Library/Application Support/DevTextMate/PlugIns/TextMateVimPlugin.tmplugin")
  `rm -Rf '#{symlink_target}'` if File.exists?(symlink_target)
  `ln -fs #{output_path} '#{symlink_target}'`
  File.open("/tmp/sample_file", "w") { |file| file.write(SAMPLE_FILE) }
  `#{DEV_TEXTMATE} /tmp/sample_file`
end

def kill_process(name)
  pid = `ps ax | grep #{name} | grep -v grep`.split(" ")[0]
  sh "kill -9 #{pid}" if pid
end
