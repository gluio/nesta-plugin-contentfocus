require "nesta-plugin-contentfocus/version"
require "nesta-plugin-contentfocus/config"
Nesta::Plugin::ContentFocus::Config.setup!
require "nesta"
Nesta::Plugin.register(__FILE__)
