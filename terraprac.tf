provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=2.16.0"
  features {}
  subscription_id = "81199c3c-1df1-4c7a-86ca-29892242b7cd"
}
# Create a resource group
resource "azurerm_resource_group" "Prod" {
  name     = "myresourcegroup01"
  location = "Central US"
}
resource "azurerm_public_ip" "Prod" {  //Here defined the public IP
  name                         = "VMpublicIP"  
  location                     = "${azurerm_resource_group.Prod.location}"  
  resource_group_name          = "${azurerm_resource_group.Prod.name}"  
  allocation_method            = "Static"  
  idle_timeout_in_minutes      = 30  
  domain_name_label            = "mylxvmachine"
}
resource "azurerm_storage_account" "Prod" {
  name                     = "wedstracc"
  resource_group_name      = "${azurerm_resource_group.Prod.name}"
  location                 = "${azurerm_resource_group.Prod.location}"
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  enable_https_traffic_only= "true"
}
resource "azurerm_storage_account_network_rules" "Prod" {
  resource_group_name  = "${azurerm_resource_group.Prod.name}"
  storage_account_name = "${azurerm_storage_account.Prod.name}"

  default_action             = "Allow"
  ip_rules                   = []
  virtual_network_subnet_ids = []
  bypass                     = ["AzureServices"]
}
resource "azurerm_storage_container" "Prod" {
  name                  = "content"
  storage_account_name  = "${azurerm_storage_account.Prod.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "Prod" {
  name                   = "mysite"
  storage_account_name   = "${azurerm_storage_account.Prod.name}"
  storage_container_name = "${azurerm_storage_container.Prod.name}"
  type                   = "Block"
  source                 = "./SITE.jpg"
}
resource "azurerm_virtual_network" "Prod" {
  name                = "myvnet01"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.Prod.location}"
  resource_group_name = "${azurerm_resource_group.Prod.name}"
}

resource "azurerm_subnet" "Prod" {
  name                 = "mysubnet01"
  resource_group_name  = "${azurerm_resource_group.Prod.name}"
  virtual_network_name = "${azurerm_virtual_network.Prod.name}"
  address_prefix       = "10.0.2.0/24"
}
resource "azurerm_network_security_group" "Prod" {
  name                = "mydemo-nsg01"
  location            = "${azurerm_resource_group.Prod.location}"
  resource_group_name = "${azurerm_resource_group.Prod.name}"

security_rule {   //Here opened remote desktop port
    name                       = "SSH"  
    priority                   = 110  
    direction                  = "Inbound"  
    access                     = "Allow" 
    protocol                   = "Tcp"  
    source_port_range          = "*"  
    destination_port_range     = "22"  
    source_address_prefix      = "*"  
    destination_address_prefix = "*"  
  }
}
resource "azurerm_network_interface" "Prod" {
  name                = "my-nic01"
  location            = "${azurerm_resource_group.Prod.location}"
  resource_group_name = "${azurerm_resource_group.Prod.name}"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = "${azurerm_subnet.Prod.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.Prod.id}"
  }
}

resource "azurerm_linux_virtual_machine" "Prod" {
  name                = "mylxvmachine"
  resource_group_name = "${azurerm_resource_group.Prod.name}"
  location            = "${azurerm_resource_group.Prod.location}"
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.Prod.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("./linuxpublickey.txt")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}
resource "azurerm_container_registry" "Prod" {
  name                     = "Hilaalcontreg"
  resource_group_name      = "${azurerm_resource_group.Prod.name}"
  location                 = "${azurerm_resource_group.Prod.location}"
  sku                      = "Premium"
  admin_enabled            = false
}

resource "azurerm_public_ip" "Prodlb" {
  name                = "PublicIPForLB"
  location            = "Central US"
  resource_group_name = "${azurerm_resource_group.Prod.name}"
  allocation_method   = "Static"
}

resource "azurerm_lb" "Prod" {
  name                = "TestLoadBalancer"
  location            = "Central US"
  resource_group_name = "${azurerm_resource_group.Prod.name}"

  frontend_ip_configuration {
    name                 = "LBPip"
    public_ip_address_id = "${azurerm_public_ip.Prodlb.id}"
  }
}
resource "azurerm_lb_backend_address_pool" "Prod" {
  resource_group_name = "${azurerm_resource_group.Prod.name}"
  loadbalancer_id     = "${azurerm_lb.Prod.id}"
  name                = "BackEndAddressPool"
}
resource "azurerm_lb_rule" "Prod" {
  resource_group_name            = "${azurerm_resource_group.Prod.name}"
  loadbalancer_id                = "${azurerm_lb.Prod.id}"
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "LBPip"
}

