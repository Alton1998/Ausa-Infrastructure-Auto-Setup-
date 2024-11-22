
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.10.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "5601380b-51b8-4c08-9f8f-27fe215a2534"
}

resource "azurerm_resource_group" "ausa_resource_group" {
  name     = "ausa-rg"
  location = var.location
}

resource "azurerm_cosmosdb_account" "ausa_cosmodb_account" {
  name                      = random_pet.prefix.id
  location                  = var.cosmosdb_account_location
  resource_group_name       = azurerm_resource_group.ausa_resource_group.name
  offer_type                = "Standard"
  kind                      = "GlobalDocumentDB"
  automatic_failover_enabled = false
  free_tier_enabled          = true
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }
  depends_on = [
    azurerm_resource_group.ausa_resource_group
  ]
  timeouts {
    create = "30m"
  }

}

resource "time_sleep" "wait_20_minutes" {
  create_duration = "20m"
  depends_on = [ azurerm_cosmosdb_account.ausa_cosmodb_account ]
}

resource "azurerm_cosmosdb_sql_database" "ausa_sql_database" {
  name                = "ausa-cosmosdb-sqldb"
  resource_group_name = azurerm_resource_group.ausa_resource_group.name
  account_name        = azurerm_cosmosdb_account.ausa_cosmodb_account.name
  throughput          = var.throughput
  depends_on = [ time_sleep.wait_20_minutes ]
}

resource "azurerm_cosmosdb_sql_container" "ausa_sql_container" {
  name                  = "ausa-sql-container"
  resource_group_name   = azurerm_resource_group.ausa_resource_group.name
  account_name          = azurerm_cosmosdb_account.ausa_cosmodb_account.name
  database_name         = azurerm_cosmosdb_sql_database.ausa_sql_database.name
  partition_key_paths    = ["/definition/id"]
  partition_key_version = 1
  throughput            = var.throughput

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    included_path {
      path = "/included/?"
    }

    excluded_path {
      path = "/excluded/?"
    }
  }

  unique_key {
    paths = ["/definition/idlong", "/definition/idshort"]
  }
  depends_on = [ time_sleep.wait_20_minutes ]
}

resource "random_pet" "prefix" {
  prefix = var.prefix
  length = 1
}