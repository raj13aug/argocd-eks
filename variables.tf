## ArgoCD server
variable "argocd_chart_version" {
  type    = string
  default = "4.9.8"
}

variable "argocd_chart_name" {
  type    = string
  default = "argo-cd"
}

variable "argocd_k8s_namespace" {
  type    = string
  default = "argo-cd"
}

## ArgoCD Image Updater
variable "argocd_image_updater_chart_version" {
  type    = string
  default = "0.8.0"
}

variable "argocd_image_updater_chart_name" {
  type    = string
  default = "argocd-image-updater"
}

variable "argocd_image_updater_k8s_namespace" {
  type    = string
  default = "argo-cd"
}