terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.49.1"
    }
  }
}

provider "hcloud" {
  token =  var.hcloud_token
}

module "private-network-with-nat-gateway" {
  source  = "lefterisALEX/private-network-with-nat-gateway/hetzner"
  version = "1.0.4"

  ssh_keys = ["main"]
}
