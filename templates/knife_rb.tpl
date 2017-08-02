current_dir = File.dirname(__FILE__)
node_name             "${chef-server-user}"
chef_server_url       "https://${chef-server-fqdn}/organizations/${organization}"
client_key            "#{current_dir}/admin.pem"
cookbook_path         "#{current_dir}/cookbooks"
trusted_certs_dir     "#{current_dir}/trusted_certs"
ssl_verify_mode :verify_none
