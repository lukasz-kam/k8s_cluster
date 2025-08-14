datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true

adminUser: admin
adminPassword: "${admin_password}"

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - "${domain}"
  path: /grafana
  pathType: Prefix

grafana.ini:
  server:
    root_url: "http://${domain}/grafana/"
    serve_from_sub_path: true

sidecar:
  dashboards:
    enabled: true
    label: grafana_dashboard
    folder: /var/lib/grafana/dashboards
    searchNamespace: ALL