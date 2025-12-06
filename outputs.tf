output "control_plane_public_ip" {
  description = "Public IP of the control plane node"
  value = aws_instance.k8s["control-plane"].public_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value = [
    aws_instance.k8s["worker-1"].public_ip,
    aws_instance.k8s["worker-2"].public_ip
  ]
}

output "all_nodes" {
  description = "Map of all node names to public IPs"
  value = {
    for name, inst in aws_instance.k8s :
    name => inst.public_ip
  }
}
