{%- set activate = salt['pillar.get']("activate") %}
{%- set app_name = activate.app_name %}
{%- set deployment = salt['pillar.get']('stacks:{}'.format(app_name)) %} # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile(i.e., minion ID 'salt' becomes 'salt_master')
{%- set active_version = activate.version | default(deployment.version) %}
{%- set docker_prefix = "{}_{}".format(app_name, active_version ) %}
{%- set active_network = "{}_network".format(docker_prefix) %}
update_backends:
  salt.state:
    - tgt: {{ deployment.loadbal.target }}
    - tgt_type: {{ deployment.loadbal.target_type }}
    - sls:
      - haproxy
    - pillar:
        haproxy:
          docker_config:
            networks:
              - {{ deployment.loadbal.default_network }}
              - {{ active_network }}
          config:
            frontends:
              {{ deployment.loadbal.frontend }}: # Parameterize
                http_proxy:
                  use_backends: []
                  default_backend: active
            backends:
              active:
                http_proxy:
                  docker_local:
                    enabled: true
                    port: {{ deployment.loadbal.backend_port }}
                    filters:
                      label:
                        - register_backend=true
                        - version={{ active_version }}
