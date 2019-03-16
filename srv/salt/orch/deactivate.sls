{%- set pillar = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'minion-debian'})['orch']['app'] %}
{%- set old_image = pillar['docker_config']['image'] %}
{%- set new_image = "nginx:1.15" %} # Pull from pillar
{%- set binds = ['/etc/nginx/conf.d/green.conf:/etc/nginx/conf.d/default.conf'] %} # Parameter

update_haproxy:
  salt.state:
    - tgt: minion-debian
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              linode.example.com:
                http_proxy:
                  default_backend: release
            backends:
              release:
                http_proxy:
                  enabled: true
                  docker_local:
                    port: {{ pillar['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }} # Parameter

{% do pillar['docker_config'].update({'image': old_image, 'state': "absent", 'force': True}) %}
deactivate_old_stack:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(pillar['count']) %}
            "{{ pillar['name_prefix'] }}_{{ pillar['docker_config']['image'] | replace(':', '_') }}-{{ i }}":
              {{ pillar['docker_config'] | yaml }}
          {% endfor %}
    - onsuccess:
      - salt: update_haproxy


prune_old_backends:
  salt.state:
    - tgt: minion-debian
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              linode.example.com: # Parameterize
                http_proxy:
                  use_backends: []
                  default_backend: active
            backends:
              active:
                http_proxy:
                  docker_local:
                    port: {{ pillar['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }}
    - onsuccess:
      - salt: deactivate_old_stack
