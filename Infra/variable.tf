variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "apim_name" {
  description = "APIM instance name"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email address"
  type        = string
}

variable "publisher_name" {
  description = "Publisher name"
  type        = string
}

variable "sku_name" {
  description = "APIM SKU - Developer_1 or Consumption_0"
  type        = string
  default     = "Developer_1"
}

variable "backend_1_url" {
  description = "Backend 1 URL (primary - ca-fastapi)"
  type        = string
}

variable "backend_2_url" {
  description = "Backend 2 URL (failover - ca-fastapi-2)"
  type        = string
}

variable "backend_1_resource_id" {
  description = "Backend 1 Azure resource ID"
  type        = string
}

variable "backend_2_resource_id" {
  description = "Backend 2 Azure resource ID"
  type        = string
}

variable "api_path" {
  description = "API path suffix in APIM"
  type        = string
  default     = "rag"
}

variable "cache_duration" {
  description = "APIM cache duration in seconds"
  type        = number
  default     = 60
}

variable "backend_timeout" {
  description = "Backend request timeout in seconds"
  type        = number
  default     = 30
}

variable "cycle_size" {
  description = "Total cycle size for backend routing"
  type        = number
  default     = 8
}

variable "backend1_switch_at" {
  description = "Number of requests before switching to backend 2"
  type        = number
  default     = 4
}

variable "circuit_breaker_trip_duration" {
  description = "Circuit breaker trip duration in ISO 8601 format"
  type        = string
  default     = "PT30S"
}

variable "circuit_breaker_failure_count" {
  description = "Failures before tripping circuit breaker"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    project     = "uniview-rag"
  }
}
