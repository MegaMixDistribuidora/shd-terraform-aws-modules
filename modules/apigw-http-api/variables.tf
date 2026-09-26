variable "name" {
  description = "API name (e.g. megamix-api)."
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
  description = "Allowed CORS origins. Wildcard is not allowed."
  type        = list(string)

  validation {
    condition     = length(var.cors_allowed_origins) > 0 && alltrue([for o in var.cors_allowed_origins : o != "*"])
    error_message = "cors_allowed_origins must list explicit origins and cannot contain \"*\"."
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
  description = "JWT authorizers keyed by name (e.g. customers, staff)."
  type = map(object({
    issuer   = string
    audience = list(string)
  }))

  validation {
    condition     = length(var.jwt_authorizers) > 0
    error_message = "jwt_authorizers must contain at least one authorizer."
  }
}

variable "domain_name" {
  description = "Custom domain for the API (e.g. api.example.com)."
  type        = string
}

variable "certificate_arn" {
  description = "Regional ACM certificate ARN covering domain_name."
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone id where the alias record is created."
  type        = string
}

variable "access_log_retention_days" {
  description = "CloudWatch retention for the access log."
  type        = number
  default     = 30
}
