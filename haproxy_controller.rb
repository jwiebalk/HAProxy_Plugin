#!/usr/bin/ruby
# this is myserver_control.rb
#
require 'rubygems'        # if you use RubyGems
require 'daemons'
#
Daemons.run('haproxy_listener.rb')
