output "control_node_public_ip" {
  value = aws_instance.control_node.public_ip
}

output "control_node_private_ip" {
  value = aws_instance.control_node.*.private_ip
}
