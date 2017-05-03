#
# Copyright 2017 SUSE Linux GmbH
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
# limitation.
#

monasca_node = node_search_with_cache("roles:monasca-server").first

package "monasca-kibana-plugin" do
  notifies :run, "execute[install monasca-kibana-plugin]", :delayed
end

service "kibana"

plugin_path = IO.popen('rpm -ql monasca-kibana-plugin | grep tar.gz', &:read).chomp!

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_node)
pub_net_ip = CrowbarHelper.get_host_for_public_url(monasca_node, false, false)

template "/etc/kibana/kibana.yml" do
  source "kibana.yml.erb"
  owner "root"
  group "root"
  mode "0444"
  notifies :restart, "service[kibana]"
  variables(
    port: 5601,
    bind_address: pub_net_ip,
    elasticsearch_url: "http://#{pub_net_ip}:9200",
    plugin: {
      'monasca-kibana-plugin.enabled' => true,
      'monasca-kibana-plugin.auth_uri' => keystone_settings["public_auth_url"],
      'monasca-kibana-plugin.cookie.isSecure' => false
      }
  )
end

execute "install monasca-kibana-plugin" do
  command "/opt/kibana/bin/kibana plugin " \
          "--install monasca-kibana-plugin " \
          "--url #{plugin_path}"
  action :nothing
end
