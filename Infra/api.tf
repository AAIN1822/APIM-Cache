# ==========================================
# APIM Subscription - Master
# ==========================================
resource "azurerm_api_management_subscription" "master" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  display_name        = "Master Subscription"
  state               = "active"
  allow_tracing       = false
}

# ==========================================
# APIM Product
# ==========================================
resource "azurerm_api_management_product" "rag_product" {
  product_id            = "rag-product"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = var.resource_group_name
  display_name          = "RAG Product"
  subscription_required = true
  approval_required     = false
  published             = true
}

# ==========================================
# Link API to Product
# ==========================================
resource "azurerm_api_management_product_api" "rag_product_api" {
  api_name            = azurerm_api_management_api.rag_api.name
  product_id          = azurerm_api_management_product.rag_product.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
}
