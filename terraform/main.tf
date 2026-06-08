provider "hcloud" {
  token = var.hcloud_token
}

data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "hcloud_firewall" "homelab" {
  name = "homelab-firewall"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

rule {
  direction = "in"
  protocol  = "tcp"
  port      = "30080"
  source_ips = ["0.0.0.0/0", "::/0"]
}

rule {
  direction = "in"
  protocol  = "tcp"
  port      = "30443"
  source_ips = ["0.0.0.0/0", "::/0"]
}
rule {
  direction  = "in"
  protocol   = "tcp"
  port       = "31000"
  source_ips = ["0.0.0.0/0", "::/0"]
}
}

resource "hcloud_server" "homelab" {
  name        = "homelab"
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  firewall_ids = [hcloud_firewall.homelab.id]

  labels = {
    environment = "homelab"
    managed_by  = "terraform"
  }
}

