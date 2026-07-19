[front]
${front_public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ssh_key_path}

[back]
${back_private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ssh_key_path} ansible_ssh_common_args='-o ProxyJump=ubuntu@${front_ip}'

[db]
${db_private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ssh_key_path} ansible_ssh_common_args='-o ProxyJump=ubuntu@${front_ip}'

[all:vars]
ansible_python_interpreter=/usr/bin/python3
