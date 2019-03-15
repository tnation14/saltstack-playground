{% for color in ["blue", "green"] %}
test_write_nginx_{{ color }}_config:
  file.managed:
    - name: /etc/nginx/conf.d/{{ color }}.conf
    - source: salt://mockup/files/{{ color }}.conf
    - mode: 0600
    - user: root
    - group: root
    - makedirs: true
    - require_in:
      - sls: docker-ce
{% endfor %}


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
