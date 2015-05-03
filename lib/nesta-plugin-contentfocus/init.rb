require 'redcarpet'
require "nesta-plugin-contentfocus/app"
Tilt.register Tilt::RedcarpetTemplate::Redcarpet2, 'markdown', 'mkd', 'md'
Tilt.prefer Tilt::RedcarpetTemplate::Redcarpet2
Nesta::Plugin::ContentFocus::Client.bootstrap!
