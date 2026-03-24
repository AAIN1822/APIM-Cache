# ==========================================
# This file documents the policy approach.
# The actual policy is applied via:
# azurerm_api_management_api_operation_policy
# in main.tf using the templatefile() function
# pointing to policies/api-policy.xml
# ==========================================

# ==========================================
# Global APIM Policy (optional)
# ==========================================
resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.apim.id

  xml_content = <<XML
<policies>
  <inbound>
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>POST</method>
        <method>GET</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>Content-Type</header>
        <header>Ocp-Apim-Subscription-Key</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound />
  <on-error />
</policies>
XML
}
