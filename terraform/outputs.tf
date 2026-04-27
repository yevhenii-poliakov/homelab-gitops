output "server_ip" {
  description = "Public IP of the homelab server"
  value       = hcloud_server.homelab.ipv4_address
}

output "server_status" {
  description = "Server status"
  value       = hcloud_server.homelab.status
}