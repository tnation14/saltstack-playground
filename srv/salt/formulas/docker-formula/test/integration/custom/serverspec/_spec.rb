require 'serverspec'

# Required by serverspec
set :backend, :exec


describe package('docker-ce') do
  it { should be_installed }
end

describe file('/etc/default/docker'), :if => os[:family] == 'debian' do
    it { should be_file }
    it { should contain 'DOCKER_HOST="-H tcp://127.0.0.1:2477 -H unix:///var/run/docker.sock"' }
    it { should contain 'DOCKER_TLS_VERIFY=False' }
    it { should be_mode 600 }
    it { should be_owned_by 'root' }
end

describe file('/etc/sysconfig/docker'), :if => os[:family] == 'redhat' do
    it { should be_file }
    it { should contain 'DOCKER_HOST="-H tcp://127.0.0.1:2477 -H unix:///var/run/docker.sock"' }
    it { should contain 'DOCKER_TLS_VERIFY=False' }
    it { should be_mode 600 }
    it { should be_owned_by 'root' }
end
