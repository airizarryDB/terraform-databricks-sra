# This resource block defines a subnet for the host
resource "azurerm_subnet" "host" {
  name                 = "webauth-host"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [local.subnet_map["webauth-host"]]

  # This delegation block specifies the actions that can be performed on the subnet by the Microsoft.Databricks/workspaces service
  delegation {
    name = "databricks-host-subnet-delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# This resource block defines a subnet for the container
resource "azurerm_subnet" "container" {
  name                 = "webauth-container"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [local.subnet_map["webauth-container"]]

  # This delegation block specifies the actions that can be performed on the subnet by the Microsoft.Databricks/workspaces service
  delegation {
    name = "databricks-container-subnet-delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# This resource block defines a network security group for webauth
resource "azurerm_network_security_group" "webauth" {
  name                = "webauth-nsg"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
}

# This resource block associates the container subnet with the webauth network security group
resource "azurerm_subnet_network_security_group_association" "container" {
  subnet_id                 = azurerm_subnet.container.id
  network_security_group_id = azurerm_network_security_group.webauth.id
}

# This resource block associates the host subnet with the webauth network security group
resource "azurerm_subnet_network_security_group_association" "host" {
  subnet_id                 = azurerm_subnet.host.id
  network_security_group_id = azurerm_network_security_group.webauth.id
}

# This resource block defines a databricks workspace for webauth
resource "azurerm_databricks_workspace" "webauth" {
  name                                  = join("_", ["WEB_AUTH_DO_NOT_DELETE", upper(azurerm_resource_group.webauth.location)])
  resource_group_name                   = azurerm_resource_group.hub.name
  location                              = azurerm_resource_group.hub.location
  sku                                   = "premium"
  public_network_access_enabled         = false
  network_security_group_rules_required = "NoAzureDatabricksRules"

  # This custom_parameters block specifies additional parameters for the databricks workspace
  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = azurerm_virtual_network.this.id
    private_subnet_name                                  = azurerm_subnet.container.name
    public_subnet_name                                   = azurerm_subnet.host.name
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.container.id
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.host.id
  }

  tags = var.tags
}

# # This resource block defines a management lock for the webauth databricks workspace
# resource "azurerm_management_lock" "webauth" {
#   name       = "webauth-do-not-delete"
#   scope      = azurerm_databricks_workspace.webauth.id
#   lock_level = "CanNotDelete"
#   notes      = "This lock is to prevent accidental deletion of the webauth workspace."
# }

# This resource block defines a private DNS zone for webauth
resource "azurerm_private_dns_zone" "webauth" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.webauth.name
}

# This resource block defines a private endpoint for webauth
resource "azurerm_private_endpoint" "webauth" {
  name                = "webauth-private-endpoint"
  location            = azurerm_resource_group.webauth.location
  resource_group_name = azurerm_resource_group.webauth.name
  subnet_id           = azurerm_subnet.privatelink.id

  # This private_service_connection block specifies the connection details for the private endpoint
  private_service_connection {
    name                           = "pl-webauth"
    private_connection_resource_id = azurerm_databricks_workspace.webauth.id
    is_manual_connection           = false
    subresource_names              = ["browser_authentication"]
  }

  # This private_dns_zone_group block specifies the private DNS zone to associate with the private endpoint
  private_dns_zone_group {
    name                 = "private-dns-zone-webauth"
    private_dns_zone_ids = [azurerm_private_dns_zone.webauth.id]
  }
}
