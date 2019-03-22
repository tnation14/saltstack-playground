# Operation Pigeon: Blue/Green Deployments for Dockerized Apps

This project is a Proof of Concept for doing doing Blue/Green deployments for docker apps on a single VM instance. It uses docker to deploy different versions of the application, and HAProxy to dynamically discover backends and route traffic between different versions. This is a stopgap measure used to setup zero-touch deployments until true discovery is available.

- [Requirements](#requirements)
- [Getting Started](#getting-started)
  - [Concepts](#concepts)
    - [Stacks](#stacks)
    - [Deployments](#deployments)
- [Project Structure](#project-structure)
  - [Minion Congfiguration](#minion-congfiguration)
  - [Application Deployment](#application-deployment)
    - [Orch pillar options](#orch-pillar-options)
- [Running a deployment](#running-a-deployment)
  - [Releasing a stack](#releasing-a-stack-)
  - [Activating a stack](#activating-a-stack)
  - [Dectivating a stack](#dectivating-a-stack-)



## TL;DR
```
pip install requests
vagrant up master debian-minion
vagrant ssh master -c "sudo salt-key -A"
./stacks.py release --app-name "app" --action "release" --version "1.14"
./stacks.py activate --app-name "app" --action "release" --version "1.14"
./stacks.py deactivate --app-name "app" --action "release" --version "1.14"
```



## Requirements
`requests`
Vagrant
VirtualBox

## Getting Started

This project consists of a salt master, and a Deb 9 minion VM. There is a CentOS minion in the Vagrantfile, but it's not used here. To get started, provision the master and debian-minion VMs, and accept the minion key on the master.
```
$ pip install requests
vagrant up master debian-minion
vagrant ssh master -c "sudo salt-key -A" # Accepts all minion keys
```

On `master`, the provisioner installs a salt master and API server, generates SSL certs for use with the app and the salt REST API, and creates a `saltapi` user for use with the deployment script. Additionally, vagrant volume mounts some simple master config files, formulas, and pillar data.

On debian-minion, the provisioner simply installs a salt minion, with the `master` VM as the salt master.

### Concepts
These are some ideas and terms used throughout the rest of this README.

#### Stacks

A stack is an Application's full infrastructure. It consists of a loadbalancer, at least one minion running at least one docker containers, and configuration files (optional). A stack has 4 states:
    - release (stack only receives internal traffic)
    - active (stack is receiving production traffic)
    - inactive (stack exists, but is receiving no traffic)
    - deactivated (stack does not exist)

A stack can be in any state, with the following constraints:
    - A stack can be in a max of one state at a time (i.e., a stack cannot be `release` and `active`).
    - A maximum one stack can be in any given state (i.e., there cannot be two release stacks).

#### Deployments
A deployment is an action that moves a stack from one state to another.

There are 3 kinds of deployments.

- `release` - moves a stack from deactivated to release.
- `activate` - move a released stack to active, AND sets the active stack to inactive.
- `deactivate` - Move a stack from any state to deactivated.

## Project Structure
This project is split into 2 parts: minion configuration and application deployment. The minion handles installing requirements necessary for deployments, and the master handles running the deployment itself. This separation ensures that deployments don't require any state to be kept on the minions, so when new minions are added to the infrastructure, they'll be in sync with the rest of the fleet.

### Minion Congfiguration
A minion should install 3 formulas:
    - docker-ce (for container management)
    - haproxy (loadbalancer/blue-green-switch)
    - A formula to Configure any app-specific files

The minion's pillar should install HAProxy using `install_method: docker` (this is ***very*** important for service discovery), and add a haproxy frontend. Configuring backends is unnecessary as deployments will add them automatically. For simplicity I kept all pillar data in the same folder, but in production, the minion pillar should live with the app config formula, which will be included in the master's `pillar_roots`

An example minion pillar can be found in [srv/salt/pillar/base/app/init.sls](../srv/salt/pillar/base/app/init.sls)

### Application Deployment
A stack is deployed from the salt master using [orchestrate runners](https://docs.saltstack.com/en/latest/topics/orchestrate/orchestrate_runner.html). Deployments can can be triggered indirectly through a reactor, or directly with `stacks.py`, which uses the salt REST api (for more information, see [Running a deployment](#running-a-deployment) below. In this project, the orchestrators live in [srv/salt/pillar/orch/](../srv/salt/pillar/orch/). There are three orchestrators, one for each deployment type.

When a deployment happens, the orchestrator pulls a stack's deployment configuration from an `orch` pillar. Like the minion pillar, this data will live with app config formulas in production. The pillar structure is as follows:
```
{% set version = my_app_version %} # Application version
{% set backend_port = 8080 %} # Port haproxy should to register backends

stacks: # Top level key for all stacks
  <app_name>:
    version: {{ version }}
    loadbal:
      target:
      target_type:
      frontend:
      backend_port: {{ backend_port }}
      default_network:
    config:
      target:
      target_type:
      formula:
    task_definitions:
      <service_name>:
        count: 1
        docker_config:
          state: running
          start: true
          restart: always
          image: myimg:{{ version }}
          ports: {{ backend_port }}
          labels:
            - register_backend=true # Set this value to add this container as a haproxy backend



```

#### Orch pillar options
The top level key for an orch pillar is the Application's name, denoted as `app_name` in the example above. The orchestrator uses this key to select deployment settings. There are 4 subkeys:

- `version`, the version of the app you'd like to deploy.
- `loadbal` - An object that manages haproxy backend discovery, controls where traffic will be directed. Available config options:

|name|type|notes|
|----|----|-----|
|`target`| string | Minion matcher
|`target_type`| string | Matcher type. See [Saltstack docs](https://docs.saltstack.com/en/latest/topics/targeting/) for available options.
|`frontend` | string | HAProxy frontend to update
|`backend_port` | int | Port where backends should be listening. Used to discover new backends when they come up.
|`default_network` | string | Docker network that the loadbalancer should use.

- `config` - An object that manages where app will be deployed. Available config options:

|name|type|notes|
|----|----|-----|
|`target`| string | Minion matcher
|`target_type`| string | Matcher type. See [Saltstack docs](https://docs.saltstack.com/en/latest/topics/targeting/) for available options.
|`formula`| string| Name of application configuration formula.

`task_definitions`: an object that manages manages container settings. Each task definition is an object where the key is the service name. and the value is a dict with these config options:
|name|type|notes|
|----|----|-----|
|docker_config| dict | Any arguments for salt state [docker_container.running](https://docs.saltstack.com/en/latest/ref/states/all/salt.states.docker_container.html#salt.states.docker_container.running)



## Running a deployment

This repo has a simple project containing a nginx web server. You can deploy different versions of nginx using with `stacks.py` in the repo root.

### Releasing a stack

In order to simulate how prod/office traffic is routed, run `curl` inside and outside of the VM.

In one terminal tab, run  `vagrant ssh debian-minion -c "while true; do curl -k https://localhost; done"`

In another, run `while true; do curl -k https://localhost:4443; done`.

You should see 503 errors in both terminals, since no backends are running. Deploy a new stack with

```
stacks.py --app-name app --version $NGINX_VERSION --action release
```
Where $NGINX_VERSION is a dockerhub tag for nginx greater than 1.13.

After 30-50s, you should see NGINX_VERSION show up in curl responses outside of the VM. You'll see 503s inside the VM because there is no active stack.


### Activating a stack

To activate the released stack, do

```
stacks.py --app-name APP_NAME --version $NGINX_VERSION --action activate

```
Where $NGINX_VERSION matches the released version. In about 20s, you should start seeing responses from nginx inside the VM.

*** Note *** you must update `version` in the pillar after activating a stack. In CI, this step will be done by Jenkins.

### Dectivating a stack

```
stacks.py --app-name APP_NAME --version NGINX_VERSION --action deactivate

```
*** Note *** This command will fail unless a version is provided.
