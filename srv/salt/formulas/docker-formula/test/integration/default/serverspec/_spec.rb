require 'serverspec'

# Required by serverspec
set :backend, :exec


describe package('docker-ce') do
  it { should_not be_installed }
end

describe file('/etc/default/docker'), :if => os[:family] == 'debian' do
    it { should_not exist }
end

describe file('/etc/sysconfig/docker'), :if => os[:family] == 'redhat' do
    it { should_not exist }
end
