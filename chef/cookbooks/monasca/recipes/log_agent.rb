# Copyright 2017 FUJITSU LIMITED
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

package "monasca-log-agent"

log_agent_settings = node[:monasca][:log_agent]
keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

log_agent_dimensions = {
  service: "monitoring",
  hostname: node["hostname"]
}
# TODO(trebskit) actually it should be retrieved from keystone
log_agent_settings["monasca_log_api_url"] = "http://www.example.org"

### create user for monasca-log-agent
register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

keystone_register "monasca-log-agent wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register monasca-log-agent user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give monasca-log-agent user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

keystone_register "register monasca-log-agent service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "monasca-log-agent"
  service_type "monitoring"
  service_description "Monasca Log Agent monitoring service"
  action :add_service
end

directory "/var/log/monasca-log-agent/" do
  owner log_agent_settings[:user]
  owner log_agent_settings[:group]
  mode 0o755
  recursive true
end
directory "/etc/monasca-log-agent/" do
  owner log_agent_settings[:user]
  owner log_agent_settings[:group]
  mode 0o755
  recursive true
end

template "/etc/monasca-log-agent/agent.conf" do
  source "log-agent.conf.erb"
  owner log_agent_settings[:user]
  owner log_agent_settings[:group]
  mode 0o640
  variables(
    log_agent_settings: log_agent_settings,
    log_agent_dimensions: log_agent_dimensions,
    keystone_settings: keystone_settings
  )
  notifies :reload, "service[monasca-log-agent]"
end

service "monasca-log-agent" do
  service_name log_agent_settings[:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:disable, :stop]
  ignore_failure true
end

node.save
