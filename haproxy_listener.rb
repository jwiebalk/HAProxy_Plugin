#!/usr/bin/ruby

require 'rubygems'
require 'stomp'
require 'yaml'
require 'fileutils'
require 'tempfile'

CONF_DIR='/etc/haproxy/conf/'
def add_haproxy(appname, namespace, ip, port, gearid)
 scope = "#{appname}-#{namespace}"
 frontfile = File.join(CONF_DIR, "frontend_http.conf")
 if File.exist?(frontfile)
if File.open(frontfile).lines.any?{|line| line.include?("#{scope}")}
	puts "already in frontend_http"
else
template = <<-EOF
\n
acl is_#{scope} hdr_dom(host) -i #{scope}
use_backend #{scope} if is_#{scope}
EOF
File.open(frontfile, 'a') { |f| f.write(template) }
`nsupdate <<EOF
server {XXX.XXX.XXX.XXXX}
zone {XXX.XXX.XXX}
update add #{scope}.{XXX.XXX.XXX} 60 CNAME {XXX.XXX.XXX.XXX}
send
quit
EOF`
end
else
puts "not found"
 end

 backfile = File.join(CONF_DIR, "backend_http.conf")
 if File.exist?(backfile)
if File.open(backfile).lines.any?{|line| line.include?("#{gearid}")}
# `sed -i 's/server #{scope}./server #{scope}.gear #{ip}:#{port} check/ /etc/haproxy/conf/frontend_http.conf`
puts "already in backend_http"
else
 template = <<-EOF

backend  #{scope}
server #{scope}.#{gearid} #{ip}:#{port} check
mode http ##{scope}
balance     roundrobin ##{scope}
option  httplog ##{scope}
option httpclose        #Disable keepalive ##{scope}
option httpchk GET / ##{scope}
option  forwardfor ##{scope}
cookie  JSESSIONID prefix ##{scope}

 EOF
 File.open(backfile, 'a') { |f| f.write(template) }
end
 else
 puts "not found"
  end

#
 `service haproxy restart`
end
def del_app(appname, namespace, ip, port, gearid)
 scope = "#{appname}-#{namespace}"
 frontfile = File.join(CONF_DIR, "frontend_http.conf")
 if File.exist?(frontfile)
if File.open(frontfile).lines.any?{|line| line.include?("#{scope}")}
findandremove(frontfile, "#{scope}")
else
puts "not in frontend_http"
end
else
puts "not found"
 end
backfile = File.join(CONF_DIR, "backend_http.conf")
 if File.exist?(backfile)
if File.open(backfile).lines.any?{|line| line.include?("#{gearid}")}
findandremove(backfile, "#{scope}")
else
puts "not in backend_http"
end
else
puts "not found"
 end

 `service haproxy restart`
end


def add_gear(appname, namespace, ip, port, gearid)
 scope = "#{appname}-#{namespace}"

 backfile = File.join(CONF_DIR, "backend_http.conf")
 if File.exist?(backfile)
if File.open(backfile).lines.any?{|line| line.include?("#{gearid}")}
puts "already in backend_http"
else
findandadd(backfile, "backend  #{scope}","server #{scope}.#{gearid} #{ip}:#{port} check")
end
 else
 puts "not found"
  end
#
 `service haproxy restart`
 end
def remove_gear(appname, namespace, ip, port, gearid)
 scope = "#{appname}-#{namespace}"
 backfile = File.join(CONF_DIR, "backend_http.conf")
 if File.exist?(backfile)
if File.open(backfile).lines.any?{|line| line.include?("#{gearid}")}
replace(backfile, /^server #{scope}.#{gearid} #{ip}:#{port} check/mi) { |match| ""}
else
puts "not in backend_http"
end
 else
 puts "not found"
  end
 `service haproxy restart`
 end

def findandadd(filepath, line_to_find, line_to_add)
temp_file = Tempfile.new(filepath)
  File.readlines(filepath).each do |line|
    temp_file.puts(line)
    temp_file.puts(line_to_add) if line.chomp == line_to_find
       end
      temp_file.close
      FileUtils.mv(temp_file.path,filepath)
      ensure
       temp_file.delete
end

def replace(filepath, regexp, *args, &block)
  content = File.read(filepath).gsub(regexp, *args, &block)
  File.open(filepath, 'wb') { |file| file.write(content) }
end

def findandremove(filepath, line_to_remove)
puts line_to_remove
temp_file = Tempfile.new(filepath)
  File.readlines(filepath).each do |line|
   temp_file.puts(line) unless line[line_to_remove]
       end
      temp_file.close
      FileUtils.mv(temp_file.path,filepath)
      ensure
       temp_file.delete
end

#
c = Stomp::Client.new("routinginfo", "routinginfopasswd", "osehaproxy.tlab.upmc.edu", 61613, true)
c.subscribe('/topic/routinginfo') { |msg|
 h = YAML.load(msg.body)
 if h[:action] == :add_public_endpoint
 if h[:types].include? "load_balancer"
 add_haproxy(h[:app_name], h[:namespace], h[:public_address], h[:public_port], h[:gear_id])
 puts "Added routing endpoint for #{h[:app_name]}-#{h[:namespace]}"
# end
elsif h[:types].include? "database"
puts "Found database for #{h[:app_name]}-#{h[:namespace]}"
puts "Database wont scale and won't be added to HAProxy"
else
add_gear(h[:app_name], h[:namespace], h[:public_address], h[:public_port], h[:gear_id])
 puts "Added routing endpoint for #{h[:app_name]}-#{h[:namespace]}"
end
 elsif h[:action] == :remove_public_endpoint
 # script does not actually act upon the remove_public_endpoint as written
 # remove gear_id from backend if gears spin down
 # remove app_id from frontend/backend if app deleted (if no gear_id remove all)
 # remove dns entry
scope = "#{h[:app_name]}-#{h[:namespace]}"
remove_gear(h[:app_name], h[:namespace], h[:public_address], h[:public_port], h[:gear_id])
puts "Removed gear for #{scope}"
elsif h[:action] == :delete_application
 scope = "#{h[:app_name]}-#{h[:namespace]}"
del_app(h[:app_name], h[:namespace], h[:public_address], h[:public_port], h[:gear_id])
 puts "Removed configuration for #{scope}"
# end
elsif h[:action] == :add_alias
scope = "#{h[:app_name]}-#{h[:namespace]}"
app_alias = "#{h[:alias]}"
puts "Found alias of #{app_alias} for #{scope}"
elsif h[:action] == :remove_alias
scope = "#{h[:app_name]}-#{h[:namespace]}"
app_alias = "#{h[:alias]}"
puts "Removing alias of #{app_alias} for #{scope}"
elsif h[:action] == :add_ssl
scope = "#{h[:app_name]}-#{h[:namespace]}"
ssl = "#{h[:ssl]}"
app_alias = "#{h[:alias]}"
puts "Found new SSL for #{ssl} for #{scope} of alias #{app_alias}"
elsif h[:action] == :remove_ssl
scope = "#{h[:app_name]}-#{h[:namespace]}"
ssl = "#{h[:ssl]}"
app_alias = "#{h[:alias]}"
puts "Removing SSL for #{ssl} for #{scope} of alias #{app_alias}"
 end
#puts msg
}
c.join
