#
# Cookbook:: build_cookbook
# Recipe:: deploy
#
# Copyright:: 2017, The Authors, All Rights Reserved.
include_recipe 'delivery-truck::deploy'

case workflow_stage
when 'delivered'
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
      command "inspec compliance upload profiles/#{profile} --overwrite"
      live_stream true
      cwd workflow_workspace_repo
    end
  end
else
  def choose_transport(platform)
    case platform
    when 'windows'
      'winrm'
    else
      'ssh'
    end
  end

  def build_knife_command(transport, admin_username, admin_password, fqdn)
    <<-EOC.gsub(/^\s+/, '')
       knife #{transport} 'fqdn:#{fqdn}' 'chef-client' -x '#{admin_username}' -P #{admin_password}
    EOC
  end

  Chef::Config.from_file(automate_knife_rb)

  workflow_environment = workflow_chef_environment_for_stage
  workflow_project = workflow_change_project

  # Get a list of infrastructure nodes by environment and recipes in run_list
  infra_nodes = search(
    :node,
    "chef_environment:#{workflow_environment} AND recipes:#{workflow_project}",
    filter_result: {
      fqdn: ['fqdn'],
      platform: ['platform']
    }
  )

  if infra_nodes.empty?
    Chef::Log.warn("No nodes returned by search: chef_environment:#{workflow_environment} AND recipes:#{workflow_project}")
  else
    vault_data = get_workflow_vault_data
    infra_nodes.each do |infra_node|
      transport = choose_transport(infra_node['platform'])
      knife_command = build_knife_command(
        transport,
        vault_data['deploy']['knife']['admin_username'],
        vault_data['deploy']['knife']['admin_password'],
        infra_node['fqdn']
      )

      execute "run chef-client on #{infra_node['fqdn']}" do
        command knife_command
        cwd delivery_workspace_repo
        sensitive true
        action :run
      end
    end
  end
end
