{%- set pillar = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'salt'})['orch']['app']['docker_config'] %}

{% set new_version = "1.14" %}
{% set binds = ['/etc/nginx/conf.d/green.conf:/etc/nginx/conf.d/default.conf'] %}
update_stack_labels:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(pillar['count']) %}
            {{ pillar['name_prefix'] }}_{{ pillar['image'] }}-{{ i }}:
              state: running
              force: true
              start: true
              restart: always
              ports: {{ pillar['port'] }}
              image: {{ pillar['image'] }}:{{ pillar['tag']}}
              labels:
                - stack=drain
              networks:
                - office
              binds:
                {%- for bind in pillar['binds']%}
                - {{ bind }}
                {%- endfor %}
          {% endfor %}
          {# Set release stacks to active #}
          {% for i in range(pillar['count']) %}
              {{ pillar['name_prefix'] }}_{{ pillar['image'] }}-release-{{ i }}:
                state: running
                force: true
                start: true
                restart: always
                ports: {{ pillar['port'] }}
                image: {{ pillar['image'] }}:{{ new_version }}
                labels:
                  - stack=active
                networks:
                  - active
                binds:
                  {%- for bind in binds | default([]) %}
                  - {{ bind }}
                  {%- endfor %}
            {% endfor %}}

remove_old_stacks:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(pillar['count']) %}
            {{ pillar['name_prefix'] }}_{{ pillar['image'] }}-{{ i }}:
              state: absent
              force: true
              start: true
              restart: always
              ports: {{ pillar['port'] }}
              image: {{ pillar['image'] }}:{{ pillar['tag']}}
              labels:
                - stack=drain
              networks:
                - prod
              binds:
                {% for bind in pillar['binds'] %}
                - {{ bind }}
                {% endfor %}
          {% endfor %}
          {% for i in range(pillar['count']) %}
              {{ pillar['name_prefix'] }}_{{ pillar['image'] }}-{{ i }}:
                state: running
                force: true
                start: true
                restart: always
                ports: {{ pillar['port'] }}
                image: {{ pillar['image'] }}:{{ pillar['tag']}}
                labels:
                  - stack=release
                networks:
                  - prod
                binds:
                  {% for bind in pillar['binds']%}
                  - {{ bind }}
                  {% endfor %}
            {% endfor %}}


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
                acls:
                  - name: release_traffic
                    condition: src 10.0.2.0/16
                    enabled: False
