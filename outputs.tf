output "service_names" {
  description = "Map of service keys to service names"
  value       = {
    for k, v in google_cloud_run_service.services : k => v.name
  }
}

output "service_urls" {
  description = "Map of service keys to service URLs"
  value       = {
    for k, v in google_cloud_run_service.services : k => try(v.status[0].url, null)
  }
}

output "service_ids" {
  description = "Map of service keys to service IDs"
  value       = {
    for k, v in google_cloud_run_service.services : k => v.id
  }
}

output "domain_mapping_records" {
  description = "Map of service keys to domain mapping records"
  value       = {
    for k, v in google_cloud_run_domain_mapping.domain_mapping : k => try(v.status[0].resource_records, [])
  }
} 