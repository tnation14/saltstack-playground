# TODO: Error handling
{%- set release = salt['pillar.get']("release") %}
{%- set app_name =  release.app_name %}
{%- set deployment = salt['pillar.get']('stacks:{}'.format(app_name)) %} # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile(i.e., minion ID 'salt' becomes 'salt_master')
{%- set release_version = release.version | default(deployment.version) %}
update_app_config:
  salt.state:
    - tgt: {{ deployment.config.target }}
    {% if deployment.config.target_type is defined %}
    - tgt_type: {{ deployment.config.target_type }}
    {% endif %}
    - highstate: true
    - pillar:
        mockup:
          version: {{ release_version }}

{%- set docker_prefix = "{}_{}".format(app_name, release.version ) %}
{%- set release_network_name = "{}_network".format(docker_prefix) %}
{%- for service, task_definition in deployment.task_definitions.items() %}
{%- set release_image = "{}:{}".format(task_definition.docker_config.image.split(":")[0], release_version) %}
{%- if task_definition.docker_config.labels is defined %}
  {%- do task_definition.docker_config.labels.append("version={}".format(release_version)) %}
{%- else %}
  {%- do task_definition.docker_config.update({"labels": ["version={}".format(release_version)] }) %}
{%- endif %}


{%- do task_definition.docker_config.update({'image': release_image, 'networks': [deployment.loadbal.default_network, {release_network_name: [{'aliases': [service]}]}]}) %}
deploy_{{ service }}_service:
  salt.state:
    - tgt: {{ deployment.config.target }}
    {% if deployment.config.target_type is defined %}
    - tgt_type: {{ deployment.config.target_type }}
    {% endif %}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          networks:
            {{ release_network_name }}:
              state: present
          containers:
          {% for i in range(task_definition.count) %}
            "{{ docker_prefix }}_{{ service }}_{{ i }}":
              {{ task_definition.docker_config | yaml }}

          {% endfor %}
{% endfor %}
update_haproxy:
  salt.state:
    - tgt: {{ deployment.loadbal.target }}
    {% if deployment.loadbal.target_type is defined %}
    - tgt_type: {{ deployment.loadbal.target_type }}
    {% endif %}
    - sls:
      - haproxy
    - pillar:
        haproxy:
          docker_config:
            networks:
            - {{ deployment.loadbal.default_network }}
          config:
            frontends:
              {{ deployment.loadbal.frontend }}: # Parameterize
                acls:
                  - name: release_traffic
                    condition: src 10.0.2.0/16 # Eventually, this will be the office IPs
                    enabled: True
                http_proxy:
                  use_backends:
                    - name: release
                      condition: "if release_traffic"
                  default_backend: active
            backends:
              release:
                http_proxy:
                  docker_local:
                    enabled: True
                    port: {{ deployment.loadbal.backend_port }}
                    filters:
                      label:
                        - register_backend=true
                        - version={{ release_version }} # Parameter
              active:
                http_proxy:
                  docker_local:
                    enabled: True
                    port: {{ deployment.loadbal.backend_port }}
                    filters:
                      label:
                        - register_backend=true
                        - version={{ deployment.version }} # Pull from pillar
## TODO update pillar after health-check
