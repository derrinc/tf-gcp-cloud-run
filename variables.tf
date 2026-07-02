variable "project_id" {
  description = "The GCP Project ID where the Cloud Run service will be created"
  type        = string
}

variable "region" {
  description = "The region where the Cloud Run service will be deployed"
  type        = string
}

variable "services" {
  description = "Map of Cloud Run services to create"
  type = map(object({
    name               = string
    image              = optional(string)
    cpu                = optional(string, "100m")
    memory             = optional(string, "128Mi")
    container_concurrency = optional(number, 80)
    domain_mapping     = optional(bool, false)
    domain_name        = optional(string, "")
    environment_variables = optional(map(string), {})
    environment_secrets = optional(map(object({
      secret_name = string
      secret_key  = string
    })), {})
    labels             = optional(map(string), {})
    service_account_name = optional(string)
  }))
}

variable "labels" {
  description = "Labels to apply to the Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "shared_artifact_registry_project" {
  description = "The GCP Project ID where the shared Artifact Registry exists"
  type        = string
  default     = ""
}

variable "dns_project_id" {
  description = "The GCP Project ID where the DNS zone exists (shared project)"
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "The name of the DNS zone in the shared project"
  type        = string
  default     = ""
}

variable "environment_secrets" {
  description = "Map of environment variable names to secret references"
  type = map(object({
    secret_name = string
    secret_key  = string
  }))
  default = {}
}

variable "default_service_account_email" {
  description = "Default service account email to use for Cloud Run services"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "database_config" {
  description = "Database configuration for services that need it"
  type = object({
    enabled = bool
    secret_name_prefix = string
  })
  default = {
    enabled = false
    secret_name_prefix = ""
  }
} 