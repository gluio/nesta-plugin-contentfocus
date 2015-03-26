require 'redcarpet'
require "nesta-plugin-drop/app"
Tilt.prefer Tilt::RedcarpetTemplate
Nesta::Plugin::Drop::Client.bootstrap!
