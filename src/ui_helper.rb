# Methods for showing UI inside of Textmate, like alerts and HTML windows. It makes use of the
# "tm_dialog" command, which Alan wrote to aid with scripting Textmate. It ships with Textmate, as a plugin.
# It's very much undocumented, but you can view its help message (run it from the command line with -h) and
# more usefully, you can check out the entire textmate SVN repo and grep for '$DIALOG' to see how bundle
# authors are using it.
class UiHelper

  def self.run_tm_dialog(options_string)
    # When writing bundles in Textmate, the $DIALOG environment variable is set for you. That should point to
    # tm_dialog. We don't have that environment variable available here, so we must divine its path ourselves.
    # TODO(philc): Don't hard-code this.
    tm_support_path = "/Applications/TextMate.app/Contents/PlugIns/Dialog.tmplugin/Contents/Resources"

    # We must tell the dialog command which textmate instance to talk to. This is essentially the process ID
    # of textmate. See this usage message for reference:
    # http://old.nabble.com/Concerning-tm_dialog-td18179878.html
    textmate_process_id = Process.ppid
    dialog_port = "com.macromates.dialog_1.#{textmate_process_id}"
    `DIALOG_1_PORT_NAME="#{dialog_port}" #{tm_support_path}/tm_dialog #{options_string}`
  end

  def self.show_alert(title, message)
    # Options are specified as a plist, unfortunately.
    title = title.gsub('"', '\"').gsub("'", "\\'")
    message = message.gsub('"', '\"').gsub("'", "\\'")
    options_plist = %Q({messageTitle="#{title}"; alertStyle="critial"; informativeText="#{message}"; })
    run_tm_dialog("-e -p '#{options_plist}'")
  end
end