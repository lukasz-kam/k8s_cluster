resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus" {
  depends_on = [kubernetes_namespace.monitoring]
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = "monitoring"
}

resource "helm_release" "grafana" {
  depends_on = [kubernetes_namespace.monitoring]
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"

  values = [
    templatefile("./grafana-values.yaml.tpl", {
      admin_password = var.grafana_admin_password
      domain         = var.domain
    })
  ]
}

resource "kubernetes_config_map" "grafana_memory_dashboard" {
  metadata {
    name      = "memory-usage-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "memory-usage.json" = file("${path.module}/dashboards/memory-usage-dashboard.json")
  }
}