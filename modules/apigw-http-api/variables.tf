variable "name" {
  description = "API name (e.g. example-api)."
  type        = string
}

variable "product" {
  description = "Product name, used in descriptions and default tags."
  type        = string
}

variable "environment" {
  description = "Environment (dev or prod)."
  type        = string
}

variable "tags" {
  description = "Tags merged into the module defaults."
  type        = map(string)
  default     = {}
}

variable "cors_allowed_origins" {
  description = "Allowed CORS origins. Empty (default) disables CORS. Wildcard is not allowed."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for o in var.cors_allowed_origins : o != "*"])
    error_message = "cors_allowed_origins cannot contain \"*\"."
  }
}

variable "cors_allowed_headers" {
  description = "Allowed CORS request headers."
  type        = list(string)
  default     = ["authorization", "content-type"]
}

variable "cors_allowed_methods" {
  description = "Allowed CORS methods."
  type        = list(string)
  default     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
}

variable "throttling_burst_limit" {
  description = "Default stage burst limit."
  type        = number
  default     = 200
}

variable "throttling_rate_limit" {
  description = "Default stage rate limit (requests per second)."
  type        = number
  default     = 100
}

variable "jwt_authorizers" {
  description = "JWT authorizers keyed by name (e.g. customers, staff). Empty (default) creates none."
  type = map(object({
    issuer   = string
    audience = list(string)
  }))
  default = {}
}

variable "domain_name" {
  description = "Custom domain for the API (e.g. api.example.com). Null (default) creates no domain, mapping or alias."
  type        = string
  default     = null

  validation {
    condition     = (var.domain_name == null) == (var.certificate_arn == null) && (var.domain_name == null) == (var.zone_id == null)
    error_message = "domain_name, certificate_arn and zone_id must be set together or omitted."
  }
}

variable "certificate_arn" {
  description = "Regional ACM certificate ARN covering domain_name. Required with domain_name."
  type        = string
  default     = null
}

variable "zone_id" {
  description = "Route53 hosted zone id where the alias record is created. Required with domain_name."
  type        = string
  default     = null
}

variable "access_log_retention_days" {
  description = "CloudWatch retention for the access log."
  type        = number
  default     = 30
}
