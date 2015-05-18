require "nesta-plugin-contentfocus/version"
require "nesta-plugin-contentfocus/config"
require "nesta"
Nesta::Plugin.register(__FILE__)
Nesta::Plugin::ContentFocus::Config.setup!
