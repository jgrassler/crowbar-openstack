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
# limitations under the License.
#

return unless node["roles"].include?("monasca-agent")

bind_port = node[:cinder][:api][:bind_port]

if node[:cinder][:ha][:enabled]
  bind_host = CrowbarPacemakerHelper.cluster_vip(node, "admin")
else
  bind_host = CinderHelper.get_bind_host_port(node)[0]
end

monitor_url = "#{node[:cinder][:api][:protocol]}://#{bind_host}:#{bind_port}/"

monasca_agent_plugin_http_check "http_check for cinder-api" do
  built_by "cinder-controller"
  name "volume-api"
  url monitor_url
  dimensions "service" => "volume-api"
  match_pattern ".*v3.*"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for cinder DB" do
  built_by "cinder-controller"
  host db_settings[:address]
  username node[:cinder][:db][:user]
  password node[:cinder][:db][:password]
  dbname node[:cinder][:db][:database]
end
