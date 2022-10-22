module "iam_assumable_role_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.2.0"

  create_role                   = true
  role_name                     = "k8s-argocd-admin"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = []
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.argocd_k8s_namespace}:argocd-server", "system:serviceaccount:${var.argocd_k8s_namespace}:argocd-application-controller"]
}

module "iam_assumable_role_oidc_argocd_image_updater" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.2.0"

  create_role                   = true
  role_name                     = "k8s-argocd-image-updater"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.argocd_k8s_namespace}:argocd-image-updater"]
}

resource "kubernetes_namespace" "namespace_argocd" {
  metadata {
    name = var.argocd_k8s_namespace
  }
}

resource "helm_release" "argocd" {

  name       = var.argocd_chart_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = var.argocd_chart_name
  version    = var.argocd_chart_version
  namespace  = var.argocd_k8s_namespace
  values     = [file("${path.module}/templates/argocd/values.yaml")]

  ## Server params
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set { # Enable Horizontal Pod Autoscaler () for the Argo CD server
    name  = "server.autoscaling.enabled"
    value = "true"
  }

  set { # Maximum number of replicas for the Argo CD server HPA
    name  = "server.autoscaling.maxReplicas"
    value = "4"
  }

  set { # Minimum number of replicas for the Argo CD server HPA
    name  = "server.autoscaling.minReplicas"
    value = "1"
  }

  set { # Average CPU utilization percentage for the Argo CD server HPA
    name  = "server.autoscaling.targetCPUUtilizationPercentage"
    value = "60"
  }

  set { # Average memory utilization percentage for the Argo CD server HPA
    name  = "server.autoscaling.targetMemoryUtilizationPercentage"
    value = "70"
  }

  set { # Manage Argo CD configmap (Declarative Setup)
    name  = "server.configEnabled"
    value = "true"
  }

  set { # Argo CD server name
    name  = "server.name"
    value = "argocd-server"
  }

  set { # Enable an ingress resource for the Argo CD server for dedicated gRPC-ingress
    name  = "server.ingressGrpc.enabled"
    value = "true"
  }

  set { # List of ingress hosts for dedicated gRPC-ingress
    name  = "server.ingressGrpc.hosts"
    value = "argocd.esp.mgmt"
  }

  set { # Defines which ingress controller will implement the resource gRPC-ingress
    name  = "server.ingressGrpc.ingressClassName"
    value = "alb"
  }

  set { # Setup up gRPC ingress to work with an AWS ALB
    name  = "server.ingressGrpc.isAWSALB"
    value = "true"
  }

  set { # Annotations applied to created service account
    name  = "server.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_oidc[0].iam_role_arn
  }

  set { # Define the application controller --app-resync - refresh interval for apps, default is 180 seconds
    name  = "controller.args.appResyncPeriod"
    value = "30"
  }

  set { # Define the application controller --repo-server-timeout-seconds - repo refresh timeout, default is 60 seconds
    name  = "controller.args.repoServerTimeoutSeconds"
    value = "15"
  }

  depends_on = [
    kubernetes_namespace.namespace_argocd,
    module.iam_assumable_role_oidc
  ]

}

resource "helm_release" "argocd-image-updater" {

  name       = var.argocd_image_updater_chart_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = var.argocd_image_updater_chart_name
  version    = var.argocd_image_updater_chart_version
  namespace  = var.argocd_image_updater_k8s_namespace
  values     = [file("${path.module}/templates/argocd-image-updater/values.yaml")]

  set { # Annotations applied to created service account
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_oidc_argocd_image_updater[0].iam_role_arn
  }

  depends_on = [
    helm_release.argocd,
    module.iam_assumable_role_oidc_argocd_image_updater
  ]

}