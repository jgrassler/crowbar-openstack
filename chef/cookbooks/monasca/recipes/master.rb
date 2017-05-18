#
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
#

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers)
raise "no nodes with monasca-server role found" if monasca_hosts.nil? || monasca_hosts.empty?

package "ansible"
package "monasca-installer" do
  notifies :run, "execute[force running ansible]", :delayed
end

cookbook_file "/etc/ansible/ansible.cfg" do
  source "ansible.cfg"
  owner "root"
  group "root"
  mode "0644"
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

hosts_template =
  if monasca_hosts.length == 1
    "monasca-hosts-single.erb"
  else
    "monasca-hosts-cluster.erb"
  end

template "/opt/monasca-installer/monasca-hosts" do
  source hosts_template
  owner "root"
  group "root"
  mode "0644"
  variables(
    monasca_hosts: monasca_hosts,
    ansible_ssh_user: "root",
    keystone_host: keystone_settings["internal_url_host"]
  )
  notifies :run, "execute[run ansible]", :delayed
end

monasca_node = monasca_servers[0]
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_node)
pub_net_ip = CrowbarHelper.get_host_for_public_url(monasca_node, false, false)

curator_actions = []
curator_excluded_index = []

if node[:monasca][:elasticsearch_curator].key?(:delete_after_days)
  curator_actions.push(
    "delete_by" => "age",
    "description" => "Delete indices older than " \
                     "#{node[:monasca][:elasticsearch_curator][:delete_after_days]} days",
    "deleted_days" => node[:monasca][:elasticsearch_curator][:delete_after_days],
    "disable" => false
  )
end

if node[:monasca][:elasticsearch_curator].key?(:delete_after_size)
  curator_actions.push(
    "delete_by" => "size",
    "description" => "Delete indices larger than " \
                     "#{node[:monasca][:elasticsearch_curator][:delete_after_size]}MB",
    "deleted_size" => node[:monasca][:elasticsearch_curator][:delete_after_size],
    "disable" => false
  )
end

node[:monasca][:elasticsearch_curator][:delete_exclude_index].each do |index|
  curator_excluded_index.push(
    "index_name" => index,
    "exclude" => true
  )
end

curator_cron_config = {}
node[:monasca][:elasticsearch_curator][:cron_config].each_pair do |field, value|
  curator_cron_config[field] = value
end

template "/opt/monasca-installer/crowbar_vars.yml" do
  source "crowbar_vars.yml.erb"
  owner "root"
  group "root"
  mode "0400"
  variables(
    master_settings: node[:monasca][:master],
    keystone_settings: keystone_settings,
    kafka_settings: node[:monasca][:kafka],
    monasca_net_ip: monasca_net_ip,
    pub_net_ip: pub_net_ip,
    api_settings: node[:monasca][:api],
    log_api_settings: node[:monasca][:log_api]
    curator_actions: curator_actions,
    curator_cron_config: curator_cron_config,
    curator_excluded_index: curator_excluded_index
  )
  notifies :run, "execute[force running ansible]", :delayed
end

# This file is used to mark that ansible installer run successfully.
# Without this, it could happen that the installer was not re-tried
# after a failed run.
# It will contain installed versions of crowbar-openstack
# and monasca-installer. If they change re-execute ansible installer.
lock_file = "/opt/monasca-installer/.installed"

previous_versions = if Pathname.new(lock_file).file?
                      File.read(lock_file).gsub(/^$\n/, "")
                    else
                      ""
                    end

get_versions = "rpm -qa | grep -e crowbar-openstack -e monasca-installer | sort"
actual_versions = IO.popen(get_versions, &:read).gsub(/^$\n/, "")

ansible_cmd =
  "rm -f #{lock_file} " \
  "&& ansible-playbook " \
    "-i monasca-hosts -e '@/opt/monasca-installer/crowbar_vars.yml' " \
    "monasca.yml " \
  "&& echo '#{actual_versions}' > #{lock_file}"

execute "run ansible" do
  command ansible_cmd
  cwd "/opt/monasca-installer"
  only_if { actual_versions != previous_versions }
end

execute "force running ansible" do
  command ansible_cmd
  cwd "/opt/monasca-installer"
  action :nothing
end
