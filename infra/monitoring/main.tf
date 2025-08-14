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
