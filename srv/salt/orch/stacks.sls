{% set request = data.get('post', {}) %}

run_orchstrator:
  runner.state.orchestrate:
    - mods: {{ request.action }}
    - kwargs:
        pillar: {{ request.pillar | yaml }}
