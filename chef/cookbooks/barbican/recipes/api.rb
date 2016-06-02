# Copyright 2016 SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"
include_recipe "#{@cookbook_name}::common"

application_path = "/srv/www/barbican-api/"
application_exec_path = "#{application_path}/app.wsgi"

package 'openstack-barbican-api'

apache_module "deflate" do
  conf false
  enable true
end

node.normal[:apache][:listen_ports_crowbar] ||= {}

node.normal[:apache][:listen_ports_crowbar][:barbican] = { plain: [bind_port] }

# Override what the apache2 cookbook does since it enforces the ports
resource = resources(template: "#{node[:apache][:dir]}/ports.conf")
resource.variables({apache_listen_ports: node.normal[:apache][:listen_ports_crowbar].values.map{ |p| p.values }.flatten.uniq.sort})

template "#{node[:apache][:dir]}/sites-available/barbican-api.conf" do
  path "#{node[:apache][:dir]}/vhosts.d/barbican-api.conf"
  source "barbican-api.conf.erb"
  mode 0644
  variables(
    application_path: application_exec_path,
    application_exec_path: application_exec_path,
    barbican_user: node[:barbican][:user],
    barbican_group: node[:barbican][:group],
    bind_host: node[:barbican][:api][:bind_port],
    bind_port: node[:barbican][:api][:bind_host],
    logfile: node[:barbican][:api][:log],
    processes: node[:barbican][:api][:processes],
    threads: node[:barbican][:api][:threads],
  )
  notifies :reload, resources(service: "apache2")
end

apache_site "barbican-api.conf" do
  enable true
end
