# Get project data for service account
data "google_project" "project" {
  project_id = var.project_id
}

# Grant Cloud Run Service Agent role
resource "google_project_iam_member" "cloud_run_service_agent" {
  project = var.project_id
  role    = "roles/run.serviceAgent"
  member  = "serviceAccount:service-${data.google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# Grant Artifact Registry reader permission in shared project for Cloud Run service agent
resource "google_project_iam_member" "shared_project_permissions" {
  count = var.shared_artifact_registry_project != "" ? 1 : 0

  project = var.shared_artifact_registry_project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:service-${data.google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

locals {
  # Enhance service configurations with defaults and computed values
  enhanced_services = {
    for k, v in var.services : k => merge(v, {
      # Add default service account if one is provided and not already set
      service_account_name = coalesce(
        lookup(v, "service_account_name", ""),
        var.default_service_account_email
      )
      
      # Merge environment secrets with database secrets if needed
      environment_secrets = merge(
        lookup(v, "environment_secrets", {}),
        # Only add database secrets for API services when database config is enabled
        k == "api" && var.database_config.enabled ? {
          "DatabaseSettings__Password" = {
            secret_name = "${var.database_config.secret_name_prefix}-${var.environment}-db-postgres-root-password"
            secret_key  = "latest"
          }
        } : {}
      )
    })
  }
}

# Create Cloud Run service
resource "google_cloud_run_service" "services" {
  for_each = local.enhanced_services

  project  = var.project_id
  location = var.region
  name     = each.value.name

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all"  # Allow unauthenticated access
    }
    labels = merge(var.labels, lookup(each.value, "labels", {}))
  }

  template {
    metadata {
      annotations = {
        "run.googleapis.com/client-name" = "terraform"
      }
    }

    spec {
      service_account_name = each.value.service_account_name
      container_concurrency = lookup(each.value, "container_concurrency", 80)

      containers {
        image = coalesce(lookup(each.value, "image", ""), "us-docker.pkg.dev/cloudrun/container/hello")

        resources {
          limits = {
            cpu    = lookup(each.value, "cpu", "100m")
            memory = lookup(each.value, "memory", "128Mi")
          }
        }

        dynamic "env" {
          for_each = lookup(each.value, "environment_variables", {})
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = each.value.environment_secrets
          content {
            name = env.key
            value_from {
              secret_key_ref {
                name = env.value.secret_name
                key  = env.value.secret_key
              }
            }
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].env,
      template[0].spec[0].containers[0].image,
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"]
    ]
  }
}

# Allow unauthenticated access to the service
resource "google_cloud_run_service_iam_member" "public_access" {
  for_each = var.services

  project  = var.project_id
  location = var.region
  service  = google_cloud_run_service.services[each.key].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create domain mapping if enabled
resource "google_cloud_run_domain_mapping" "domain_mapping" {
  for_each = {
    for k, v in var.services : k => v
    if lookup(v, "domain_mapping", false) && lookup(v, "domain_name", "") != ""
  }

  project  = var.project_id
  location = var.region
  name     = each.value.domain_name

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_service.services[each.key].name
  }

  depends_on = [google_cloud_run_service.services]
}

# Add DNS record for the domain mapping
resource "google_dns_record_set" "domain_mapping" {
  for_each = {
    for k, v in var.services : k => v
    if lookup(v, "domain_mapping", false) && lookup(v, "domain_name", "") != ""
  }

  project      = var.dns_project_id
  name         = "${each.value.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = [google_cloud_run_domain_mapping.domain_mapping[each.key].status[0].resource_records[0].rrdata]

  depends_on = [google_cloud_run_domain_mapping.domain_mapping]
} 