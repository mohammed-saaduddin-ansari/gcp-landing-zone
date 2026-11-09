variable "parent" {
  description = "Parent of the top-level folders, in the form `organizations/123456789012` or `folders/123456789012`."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent must look like organizations/<numeric id> or folders/<numeric id>."
  }
}

variable "folders" {
  description = "Top-level folder keys to create under `parent`. The key is used as the display name unless overridden in `display_names`."
  type        = list(string)
  default     = ["bootstrap", "common", "prod", "nonprod", "sandbox"]

  validation {
    condition     = length(var.folders) == length(distinct(var.folders))
    error_message = "folders must not contain duplicates."
  }

  validation {
    condition     = alltrue([for f in var.folders : can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", f))])
    error_message = "Folder keys must be 3-30 characters of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "display_names" {
  description = "Optional display-name overrides, keyed by folder key (for example `{ prod = \"Production\" }`)."
  type        = map(string)
  default     = {}

  validation {
    # Cloud Resource Manager rule: 1-30 characters of letters, digits, spaces, hyphens and underscores,
    # starting and ending with a letter or digit.
    condition     = alltrue([for n in values(var.display_names) : can(regex("^[A-Za-z0-9]([A-Za-z0-9 _-]{0,28}[A-Za-z0-9])?$", n))])
    error_message = "Folder display names must be 1-30 characters of letters, digits, spaces, hyphens or underscores, starting and ending with a letter or digit."
  }
}

variable "subfolders" {
  description = "Optional second-level folders, keyed by top-level folder key. Example: `{ prod = [\"payments\", \"data\"] }`."
  type        = map(list(string))
  default     = {}

  validation {
    condition     = alltrue(flatten([for _, names in var.subfolders : [for n in names : can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", n))]]))
    error_message = "Subfolder names must be 3-30 characters of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "deletion_protection" {
  description = "Prevent Terraform from deleting folders. Leave this on outside of throwaway test organisations."
  type        = bool
  default     = true
}
