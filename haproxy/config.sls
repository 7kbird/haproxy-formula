{% from 'haproxy/map.jinja' import config_file with context %}
haproxy.config:
 file.managed:
   - name: {{ config_file }}
   - source: salt://haproxy/templates/haproxy.jinja
   - template: jinja
   - user: root
   - group: root
   - mode: 644
   - makedirs: True
