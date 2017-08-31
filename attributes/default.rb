default['audit']['fetcher'] = 'chef-server-automate'
default['audit']['reporter'] = 'chef-server-automate'

default['audit']['profiles'] = [
  {
    name: 'tls_win_sec',
    compliance: 'cmpl_svc/tls_win_sec',
  }
]
