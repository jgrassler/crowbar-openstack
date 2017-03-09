#
# Copyright 2016 SUSE Linux GmbH
# Copyright 2017 Fujitsu LIMITED
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

monasca_debug = false
monasca_ha_enabled = false

monasca_metric_agent_service_name = "monasca-agent"
monasca_log_agent_service_name = "monasca-log-agent"

default[:monasca][:platform] = {
  packages: [],
  services: [
    monasca_metric_agent_service_name,
    monasca_log_agent_service_name
  ]
}

default[:monasca][:db][:database] = "monasca"
default[:monasca][:db][:user] = "monasca"
default[:monasca][:db][:password] = nil # must be set by wrapper

override[:monasca][:group] = "monasca"
override[:monasca][:user] = "monasca"

default[:monasca][:debug] = monasca_debug
default[:monasca][:ha][:enabled] = monasca_ha_enabled

default[:monasca][:api][:bind_host] = "*"

# metric-agent default service settings
default[:monasca][:metric_agent][:service_name] = monasca_metric_agent_service_name
default[:monasca][:metric_agent][:user] = "monasca-agent"
default[:monasca][:metric_agent][:group] = "monasca"
default[:monasca][:metric_agent][:debug] = monasca_debug

# log-agent default service settings
default[:monasca][:log_agent][:service_name] = monasca_log_agent_service_name
default[:monasca][:log_agent][:user] = "monasca-log-agent"
default[:monasca][:log_agent][:group] = "logstash"
default[:monasca][:log_agent][:debug] = monasca_debug
