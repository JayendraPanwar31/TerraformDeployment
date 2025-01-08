provider "azurerm" {
  features {}
  subscription_id = "Your Azure Subscription"
}

# Define the resource group
resource "azurerm_resource_group" "rg" {
  name     = "JayendraEnterpriseRG"
  location = "East US"
}

# 2. Define a Virtual Network and Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "JPTestVnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-redis"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3. Create Azure Cache for Redis Enterprise (E10)
resource "azurerm_redis_enterprise_cluster" "cluster" {
  name                = "redis-enterprise-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Enterprise_E10-2"
}

 #3. Create Redis Enterprise Database for the Cluster
resource "azurerm_redis_enterprise_database" "db" {
  name              = "default"
  cluster_id        = azurerm_redis_enterprise_cluster.cluster.id
  client_protocol   = "Encrypted"
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  port              = 10000
}

# 5. Create Private Endpoint for Redis Cluster
resource "azurerm_private_endpoint" "redis_pe" {
  name                = "jptest-private-endpoint"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "jptest-private-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_redis_enterprise_cluster.cluster.id
    subresource_names = ["redisEnterprise"]
  }
}

# 6. Create Private DNS Zone for Redis Enterprise
resource "azurerm_private_dns_zone" "redis_dns_zone" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# 7. Link the DNS Zone to Virtual Network for DNS resolution
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "jp-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.redis_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
}

# Output the private IP address of the Redis Cluster Private Endpoint
output "redis_private_ip" {
  value = azurerm_private_endpoint.redis_pe.private_service_connection[0].private_ip_address
}