/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  files = [
    "audit_logging_rules.yaml",
    "bigquery_rules.yaml",
    "blacklist_rules.yaml",
    "bucket_rules.yaml",
    "cloudsql_rules.yaml",
    "enabled_apis_rules.yaml",
    "external_project_access_rules.yaml",
    "firewall_rules.yaml",
    "forwarding_rules.yaml",
    "group_rules.yaml",
    "groups_settings_rules.yaml",
    "iam_rules.yaml",
    "iap_rules.yaml",
    "instance_network_interface_rules.yaml",
    "ke_rules.yaml",
    "ke_scanner_rules.yaml",
    "kms_rules.yaml",
    "lien_rules.yaml",
    "location_rules.yaml",
    "log_sink_rules.yaml",
    "resource_rules.yaml",
    "retention_rules.yaml",
    "role_rules.yaml",
    "service_account_key_rules.yaml",
  ]

  rules_count = var.manage_rules_enabled ? length(local.files) : 0

  /*
   * If the configuration file has the rules in a bucket, we can
   * copy the rules to it or create the empty rules dir if 
   * manage_rules_enabled is false. Note: When using terraform to
   * deploy Forseti, there isn't an easy way to deploy scanner_rules
   * without using a GCS bucket
   */
  is_rules_in_bucket = length( regexall( "^gs://", var.server_config_module.rules_path ) ) > 0
  // The regex will capture the directory portion of the bucket path so that we can copy file to it
  rules_directory = is_rules_in_bucket ? regex( "^gs://[^/]+/(.*)", var.server_config_module.rules_path ) : "" 
}

data "template_file" "main" {
  count = local.rules_count
  template = file(
    "${path.module}/templates/rules/${element(local.files, count.index)}",
  )

  vars = {
    org_id = var.org_id
    domain = var.domain
  }
}

resource "google_storage_bucket_object" "main" {
  count   = local.is_rules_in_bucket ? local.rules_count : 0
  name    = "${local.rules_directory}/${element(local.files, count.index)}"
  content = element(data.template_file.main.*.rendered, count.index)
  bucket  = var.server_gcs_module.forseti-server-storage-bucket

  lifecycle {
    ignore_changes = [
      content,
      detect_md5hash,
    ]
  }
}

// When `manage_rules_enabled` is set to false, by default, `` dir won't be created.
// This resource ensures empty `` dir exists to allow Forseti service to start successfully.
resource "google_storage_bucket_object" "empty_rules_dir" {
  count   = local.is_rules_in_bucket && ! var.manage_rules_enabled ? 1 : 0
  name    = local.rules_directory
  content = "n/a"
  bucket  = var.server_gcs_module.forseti-server-storage-bucket

  lifecycle {
    ignore_changes = [
      content,
      detect_md5hash,
    ]
  }
}
