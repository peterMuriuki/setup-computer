# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "playbook.yml"
    # ansible.galaxy_role_file = "requirements.yml"
    ansible.verbose = "vv"
    ansible.raw_arguments = [
        "--extra-vars 'mosh_system_user=vagrant'"
    ]
  end

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 2
  end

  config.vm.box = "ubuntu/bionic64"
  config.ssh.forward_agent = true
end