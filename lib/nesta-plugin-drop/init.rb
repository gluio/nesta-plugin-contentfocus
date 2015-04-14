require 'redcarpet'
require "nesta-plugin-drop/app"
Tilt.register Tilt::RedcarpetTemplate::Redcarpet2, 'markdown', 'mkd', 'md'
Tilt.prefer Tilt::RedcarpetTemplate::Redcarpet2
Nesta::Plugin::Drop::Client.bootstrap!
