output "apim_gateway_url" {
  description = "APIM Gateway URL"
  value       = azurerm_api_management.apim.gateway_url
}

output "apim_name" {
  description = "APIM instance name"
  value       = azurerm_api_management.apim.name
}

output "apim_principal_id" {
  description = "APIM Managed Identity Principal ID"
  value       = azurerm_api_management.apim.identity[0].principal_id
}

output "apim_tenant_id" {
  description = "APIM Managed Identity Tenant ID"
  value       = azurerm_api_management.apim.identity[0].tenant_id
}

output "api_endpoint" {
  description = "Full API endpoint URL"
  value       = "${azurerm_api_management.apim.gateway_url}/${var.api_path}/api/query"
}

output "backend_1_id" {
  description = "Backend 1 resource ID"
  value       = azurerm_api_management_backend.backend_1.id
}

output "backend_2_id" {
  description = "Backend 2 resource ID"
  value       = azurerm_api_management_backend.backend_2.id
}

output "rag_api_id" {
  description = "RAG API resource ID"
  value       = azurerm_api_management_api.rag_api.id
}
