# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  # config.vm.box = "bento/debian-9.5"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
  config.vm.define "master" do |master|
    master.vm.box = "bento/debian-9.5"
    master.vm.hostname = "salt"

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    master.vm.network "private_network", ip: "10.0.0.2"
    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    master.vm.synced_folder "./formulas", "/srv/salt/formulas/"
    master.vm.synced_folder "./modules", "/srv/salt/modules/"
    master.vm.synced_folder "./pillar", "/srv/salt/pillar/"
    master.vm.provision "shell", inline: <<-SHELL
      echo "Setting up APT repos"
      wget -O - https://repo.saltstack.com/apt/debian/9/amd64/latest/SALTSTACK-GPG-KEY.pub | apt-key add -
      echo 'deb http://repo.saltstack.com/apt/debian/9/amd64/latest stretch main' > /etc/apt/sources.list.d/saltstack.list
      apt-get update

      echo "Installing Salt master and minion"
      apt-get install -y salt-minion salt-master
      echo "Done!"

    SHELL
  end


  config.vm.define "debian-minion" do |dminion|
    dminion.vm.box = "bento/debian-9.5"
    dminion.vm.hostname = "minion-debian"

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    dminion.vm.network "private_network", ip: "10.0.0.3"
    dminion.vm.provision "shell", inline: <<-SHELL
      echo "Setting up APT repos"
      wget -O - https://repo.saltstack.com/apt/debian/9/amd64/latest/SALTSTACK-GPG-KEY.pub | apt-key add -
      echo 'deb http://repo.saltstack.com/apt/debian/9/amd64/latest stretch main' > /etc/apt/sources.list.d/saltstack.list
      apt-get update

      echo "Installing Salt minion"
      apt-get install -y salt-minion
      echo "Done!"

    SHELL
  end

  config.vm.define "centos-minion" do |cminion|
    cminion.vm.box = "bento/centos-7.5"
    cminion.vm.hostname = "minion-centos"

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    cminion.vm.network "private_network", ip: "10.0.0.4"
    cminion.vm.provision "shell", inline: <<-SHELL
      echo "Setting up Yum repos"
      yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
      yum clean expire-cache

      yum install -y salt-minion
      systemctl start salt-minion

    SHELL
  end

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
