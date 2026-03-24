# ==========================================
# APIM Instance
# ==========================================
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ==========================================
# Role Assignments - Managed Identity
# ==========================================
resource "azurerm_role_assignment" "apim_to_backend1" {
  scope                = var.backend_1_resource_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

resource "azurerm_role_assignment" "apim_to_backend2" {
  scope                = var.backend_2_resource_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# ==========================================
# Backend 1 (Primary)
# ==========================================
resource "azurerm_api_management_backend" "backend_1" {
  name                = "fastapi-backend-1"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = var.backend_1_url
  resource_id         = "https://management.azure.com${var.backend_1_resource_id}"
  description         = "FastAPI Backend 1 - Primary"

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# ==========================================
# Backend 2 (Failover)
# ==========================================
resource "azurerm_api_management_backend" "backend_2" {
  name                = "fastapi-backend-2"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = var.backend_2_url
  resource_id         = "https://management.azure.com${var.backend_2_resource_id}"
  description         = "FastAPI Backend 2 - Failover"

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# ==========================================
# Load Balancer Pool via REST API
# (Pool type not supported in AzureRM yet)
# ==========================================
resource "null_resource" "lb_pool" {
  depends_on = [
    azurerm_api_management_backend.backend_1,
    azurerm_api_management_backend.backend_2
  ]

  triggers = {
    apim_name   = azurerm_api_management.apim.name
    backend1_id = azurerm_api_management_backend.backend_1.id
    backend2_id = azurerm_api_management_backend.backend_2.id
  }

  provisioner "local-exec" {
    command = <<EOT
TOKEN=$(az account get-access-token --query accessToken --output tsv)
curl -s -X PUT \
  "https://management.azure.com/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_name}/backends/fastapi-lb-pool?api-version=2023-05-01-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"properties":{"description":"FastAPI LB Pool","type":"Pool","pool":{"services":[{"id":"/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_name}/backends/fastapi-backend-1","weight":1,"priority":1},{"id":"/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_name}/backends/fastapi-backend-2","weight":1,"priority":2}]}}}'
EOT
  }
}

# ==========================================
# Circuit Breaker on Backend 1 via REST API
# ==========================================
resource "null_resource" "circuit_breaker" {
  depends_on = [azurerm_api_management_backend.backend_1]

  triggers = {
    backend1_url           = var.backend_1_url
    trip_duration          = var.circuit_breaker_trip_duration
    failure_count          = var.circuit_breaker_failure_count
  }

  provisioner "local-exec" {
    command = <<EOT
TOKEN=$(az account get-access-token --query accessToken --output tsv)
curl -s -X PUT \
  "https://management.azure.com/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_name}/backends/fastapi-backend-1?api-version=2023-05-01-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "url": "${var.backend_1_url}",
      "protocol": "http",
      "resourceId": "https://management.azure.com${var.backend_1_resource_id}",
      "description": "FastAPI Backend 1 with Circuit Breaker",
      "circuitBreaker": {
        "rules": [{
          "name": "failover-rule",
          "failureCondition": {
            "count": ${var.circuit_breaker_failure_count},
            "interval": "PT60S",
            "statusCodeRanges": [
              {"min": 500, "max": 599},
              {"min": 429, "max": 429}
            ],
            "errorReasons": ["Timeout", "ConnectionFailure"]
          },
          "tripDuration": "${var.circuit_breaker_trip_duration}",
          "acceptRetryAfter": true
        }]
      }
    }
  }'
EOT
  }
}

# ==========================================
# API Definition
# ==========================================
resource "azurerm_api_management_api" "rag_api" {
  name                  = "rag-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "RAG API"
  path                  = var.api_path
  protocols             = ["https"]
  subscription_required = true
}

# ==========================================
# API Operation - POST /api/query
# ==========================================
resource "azurerm_api_management_api_operation" "query" {
  operation_id        = "query"
  api_name            = azurerm_api_management_api.rag_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  display_name        = "Query"
  method              = "POST"
  url_template        = "/api/query"
  description         = "Query the RAG system"

  request {
    description = "Query request"
    representation {
      content_type = "application/json"
      example {
        name  = "default"
        value = jsonencode({ question = "Who is Narendra Modi?" })
      }
    }
  }

  response {
    status_code = 200
    description = "Successful response"
  }

  response {
    status_code = 401
    description = "Unauthorized"
  }

  response {
    status_code = 500
    description = "Internal server error"
  }
}

# ==========================================
# API Operation Policy
# ==========================================
resource "azurerm_api_management_api_operation_policy" "query_policy" {
  api_name            = azurerm_api_management_api.rag_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  operation_id        = azurerm_api_management_api_operation.query.operation_id

  xml_content = templatefile("${path.module}/policies/api-policy.xml", {
    cache_duration     = var.cache_duration
    backend_timeout    = var.backend_timeout
    cycle_size         = var.cycle_size
    backend1_switch_at = var.backend1_switch_at
  })

  depends_on = [
    azurerm_api_management_api_operation.query,
    null_resource.lb_pool,
    null_resource.circuit_breaker
  ]
}

# ==========================================
# Named Values
# ==========================================
resource "azurerm_api_management_named_value" "cache_duration" {
  name                = "cache-duration"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "cache-duration"
  value               = tostring(var.cache_duration)
}

resource "azurerm_api_management_named_value" "cycle_size" {
  name                = "cycle-size"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "cycle-size"
  value               = tostring(var.cycle_size)
}

resource "azurerm_api_management_named_value" "backend_switch_at" {
  name                = "backend-switch-at"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "backend-switch-at"
  value               = tostring(var.backend1_switch_at)
}
