#
# Cookbook:: build_cookbook
# Recipe:: syntax
#
# Copyright:: 2017, The Authors, All Rights Reserved.
include_recipe 'delivery-truck::syntax'

vault_data = get_workflow_vault_data

cmd = ''
cmd << "inspec compliance login_automate"
cmd << " \'#{vault_data['deploy']['compliance']['automate_compliance_url']}\'"
cmd << ' --insecure'
cmd << " --user=\'#{vault_data['deploy']['compliance']['compliance_username']}\'"
cmd << " --ent=\'#{workflow_change_enterprise}\'"
cmd << " --usertoken=\'#{vault_data['deploy']['compliance']['compliance_token']}\'"

execute "Login to Automate Compliance" do
  command cmd
  sensitive true
end

get_all_project_cookbooks.each do |cookbook|
  profile = cookbook.name.gsub(/_audit/, '')
  
  # Run inspec check on profile
  execute "Check if profile is valid." do
    command "inspec check profiles/#{profile}"
    live_stream true
    cwd workflow_workspace_repo
  end
end
