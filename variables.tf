variable "inspection_vpc_cidr_block" {}
variable "spoke_vpc_cidr_block" {}
variable "key_name" { default = "ludus-elb-key"}
#NWCD market place image PAN-OS 11.0.2, https://awsmarketplace.amazonaws.cn/marketplace/pp/prodview-xk56uorvk7qg4
#You can replace your own AMI here
variable "pavm_ami" {
    default = "ami-0738eadeed7e6b0fa"
    description = "Palo Alto VM-Series"
}
