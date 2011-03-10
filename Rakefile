require 'pathname'

APPNAME = "TextMateVim"
DEV_TEXTMATE = ENV["DevTextMate"] || "/Applications/DevTextMate.app/Contents/MacOS/DevTextMate"
$configuration = ENV['Configuration'] || 'Debug'

task :default => :test
task :run => :build

task :build do
  # Textmate is currently built against i386, and so must our plugin be.
  sh "xcodebuild -configuration #{$configuration} ARCHS='i386'"
end

task :run do
  exec "build/Debug/textmatevim.app/Contents/MacOS/textmatevim"
end

task :test do |task|
  Dir.glob("test/*_test.rb").each do |filename|
    sh "ruby #{filename}"
  end
end

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

task :release_bundle do
  $configuration = "Release"
  Rake::Task["build"].invoke
  `mv "build/release/#{APPNAME}.bundle" "build/release/#{APPNAME}.tmplugin"`
  `zip -r build/release/#{APPNAME}.tmbundle.zip build/release/#{APPNAME}.tmplugin`
end

def kill_process(name)
  pid = `ps ax | grep #{name} | grep -v grep`.split(" ")[0]
  sh "kill -9 #{pid}" if pid
end

# We open this file in textmate to play around with the editing features of our plugin.
SAMPLE_FILE = <<-EOF
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n

  # Executes a single command and returns the response which should be sent to textmate.
  def execute_command(command)
    self.key_queue = []
    result = self.send(command.to_sym)
    # When executing commands which modify the document, keep track of the original cursor position
    # so we can    restore it when we unwind these commands via undo.
    if MUTATING_COMMANDS.include?(command)
      previous_command_stack.push(
          { :command => command, :line => @event["line"], :column => @event["column"]})
      previous_command_stack.shift if previous_command_stack.size > UNDO_STACK_SIZE
    end
    result
  end
EOF
