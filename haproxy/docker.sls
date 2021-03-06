{% set image = salt['pillar.get']('haproxy:docker:image', 'haproxy') %}
{% set docker = salt['pillar.get']('haproxy:docker', {}) %}

haproxy-docker-image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }}{{ ':latest' if not ':' in image }}) ]'

{% from 'haproxy/map.jinja' import depend_dockers with context %}

{% set no_ip_dockers = [] %}
{% for depend in depend_dockers %}
  {% if (depend not in salt['dockerng.list_containers']()) or
        ( not salt['dockerng.inspect_container'](depend).NetworkSettings.IPAddress) %}
    {% do no_ip_dockers.append(depend) %}
  {% endif %}
{% endfor %}

{% if no_ip_dockers|length > 0 %}
haproxy-depend-dockers-ip-not-found:
  test.fail_without_changes:
    - name: 'depend docker of haproxy is not started:[{{ no_ip_dockers|join(',') }}]'

{% else %}
{% from 'haproxy/map.jinja' import config_file with context %}
haproxy-docker-running_{{ image }}:
  dockerng.running:
    - name: {{ docker.get('name', 'haproxy') }}
    - image: {{ image }}
    {% if 'port_bindings' in docker %}
    - port_bindings:
      {% for port_binding in docker.port_bindings %}
      - {{ port_binding }}
      {% endfor %}
    {% endif %}
    {% if 'ports' in docker%}
    - ports:
      {% for port in docker.ports %}
      - {{ port }}
      {% endfor %}
    {% endif %}
    - binds:
      - {{ config_file}}:{{ docker.get('config_file', '/usr/local/etc/haproxy/haproxy.cfg:ro') }}
      {% for bind in docker.get('binds', []) %}
      - {{ bind }}
      {% endfor %}
    - require:
      - cmd: haproxy-docker-image_{{ image }}
      {% for depend in depend_dockers %}
      - dockerng: {{ depend }}
      {% endfor %}
    {% if 'watch' in docker %}
    - watch:
      {% for watch in docker.get('watch', []) %}
      - {{ watch }}
      {% endfor %}
    {% endif %}
    {% if 'require' in docker %}
    - require:
      {% for require in docker.get('require', []) %}
      - {{ require }}
      {% endfor %}
    {% endif %}
include:
  - haproxy.config
extend:
  haproxy.config:
    file.managed:
      - watch_in:
        - dockerng: haproxy-docker-running_{{ image }}
{% endif %}
