# Ensure the Automate Asset Store is enabled and trigger a reconfigure otherwise
replace_or_add "Enable profiles in Automate" do
  path "/etc/delivery/delivery.rb"
  pattern "^compliance_profiles['enable'].*"
  line "compliance_profiles['enable'] = true"
  notifies :run, "execute[automate_reconfigure]", :immediately
end

execute 'automate_reconfigure' do
  command <<-EOH
    automate-ctl reconfigure
  EOH
  action :nothing
end


# Because we snapshot the instance
delete_lines "Avoid cookbook storage in S3" do
  path "/etc/opscode/chef-server.rb"
  pattern "^opscode_erchef.+base_resource_url"
  notifies :run, "execute[chef_reconfigure]", :immediately
end

replace_or_add "Enable forwarding of profiles to Automate" do
  path "/etc/opscode/chef-server.rb"
  pattern "profiles['root_url'].*"
  line "profiles['root_url'] = 'https://localhost'"
  notifies :run, "execute[chef_reconfigure]", :immediately
end

execute 'chef_reconfigure' do
  command <<-EOH
    chef-server-ctl reconfigure
  EOH
  action :nothing
end
