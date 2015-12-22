Openshift Ruby plugin for External HAProxy

Requires HAProxy to be configured in 4 seperate conf files

/etc/haproxy/haproxy.cfg
/etc/haproxy/conf/admin.conf
/etc/haproxy/conf/backend_http.conf
/etc/haproxy/conf/frontend_http.conf

controller requires "gem install daemons"

Controller use:
scl enable ruby193 "ruby haproxy_controller.rb start"

Inside /etc/openshift/broker.conf on broker node set:
ALLOW_HA_APPLICATIONS="true"

Also allow user to create HA applications

oo-admin-ctl-user -l $user --allowha true
