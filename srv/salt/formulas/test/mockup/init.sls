{% for color in ["blue", "green"] %}
test_write_nginx_{{ color }}_config:
  - name: /etc/nginx/conf.d/{{ color }}.conf
  - source: salt://files/{{ color }}
  - mode: 0600
  - user: root
  - group: root
  - makedirs: true
{% endfor %}


