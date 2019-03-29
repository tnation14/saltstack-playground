{% set mockup = salt['pillar.get']('mockup') %}

include:
  - 'docker-ce'

test_write_nginx_config:
  file.managed:
    - name: /etc/nginx/conf.d/default.conf
    - source: salt://mockup/files/default.conf
    - mode: 0600
    - user: root
    - group: root
    - makedirs: true
    - template: jinja
    - require_in:
      - sls: docker-ce

test_write_django_src:
  file.recurse:
    - name: /opt/app
    - source: salt://test/django
    - clean: true
    - dir_mode: 0644
    - replace: true

test_write_django_dockerfile:
  file.managed:
    - name: /opt/app/Dockerfile
    - source: salt://mockup/files/Dockerfile
    - clean: true
    - dir_mode: 0644
    - replace: true
    - template: jinja
    - require_in:
      - docker_image: test_build_django_image

test_build_django_image:
  docker_image.present:
    - name: myapp
    - tag: {{ mockup.version }}
    - build: /opt/app
    - watch:
      - file: test_write_django_src
      - file: test_write_django_dockerfile

test_pull_nginx_image:
  docker_image.present:
    - name: nginx:1.15

test_tag_nginx_image:
  cmd.run:
    - name: docker tag nginx:1.15 myapp-nginx:{{ mockup.version }}
    - unless: '[ $(docker images -q myapp:{{ mockup.version }}) | wc -l ]'
    - require:
      - docker_image: test_pull_nginx_image

test_mockup_ssl_create_ca:
  module.run:
    - name: tls.create_ca
    - ca_name: linode_test_ca
    - cacert_path: /etc/ssl/certs
    - ca_filename: linode_internal_ca.pem
    - days: 5
    - CN: 'Linode Test CA'
    - C: US
    - ST: NJ
    - L: Galloway
    - O: Linode Testing
    - emailAddress: systems@example.com
    - unless: '[ -f /etc/ssl/certs/linode_test_ca/linode_internal_ca.pem.key ]'


test_mockup_ssl_create_csr:
  module.run:
    - name: tls.create_csr
    - ca_name: linode_test_ca
    - cacert_path: /etc/ssl/certs
    - ca_filename: linode_internal_ca.pem
    - CN: example.com
    - unless: '[ -f /etc/ssl/certs/linode_test_ca/certs/example.com.key ]'
    - require:
      - module: test_mockup_ssl_create_ca

test_mockup_ssl_sign_csr:
  module.run:
    - name: tls.create_ca_signed_cert
    - ca_name: linode_test_ca
    - cacert_path: /etc/ssl/certs
    - ca_filename: linode_internal_ca.pem
    - CN: example.com
    - unless: '[ -f /etc/ssl/certs/linode_test_ca/certs/example.com.crt ]'
    - require:
      - module: test_mockup_ssl_create_csr

test_mockup_create_concatenated_pem:
  cmd.run:
    - name: "cat /etc/ssl/certs/linode_test_ca/certs/example.com.crt /etc/ssl/certs/linode_test_ca/certs/example.com.key > /etc/ssl/certs/example.com.pem"
    - unless: '[ -f /etc/ssl/certs/example.com.pem ]'
    - require:
      - module: test_mockup_ssl_sign_csr
    - require_in:
      - sls: haproxy
