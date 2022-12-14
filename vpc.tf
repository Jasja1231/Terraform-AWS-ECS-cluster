
#=====================================================================
#Creating VPC - terr_vpc only local terraform name
#=====================================================================

resource "aws_vpc" "terr_vpc" {
  cidr_block = "10.1.0.0/16"  #65,536

  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Name = "terr-vpc"
  }
}


#Subnets (3 availability zone)
#Public 
resource "aws_subnet" "terr_pub_subnet" {
  vpc_id            = aws_vpc.terr_vpc.id
  cidr_block        = "10.1.1.0/24" #256
  availability_zone = "eu-central-1a"
  #- (Optional) Specify true to indicate that instances 
  #launched into the subnet should be assigned a public IP address.
  map_public_ip_on_launch = true

  tags = {
    Name = "terr-public-subnet-1a"
  }
}

resource "aws_subnet" "terr_pub_subnet_1b" {
  vpc_id            = aws_vpc.terr_vpc.id
  cidr_block        = "10.1.2.0/24" 
  availability_zone = "eu-central-1b"
  #- (Optional) Specify true to indicate that instances 
  #launched into the subnet should be assigned a public IP address.
  map_public_ip_on_launch = true

  tags = {
    Name = "terr-public-subnet-1b"
  }
}

#Private for RDS
resource "aws_subnet" "terr_priv_subnet_1a" {
  vpc_id            = aws_vpc.terr_vpc.id
  cidr_block        = "10.1.160.0/24" #256 
  availability_zone = "eu-central-1a"

  tags = {
    Name = "terr-private-subnet-1azone"
  }
}

#Private for RDS
resource "aws_subnet" "terr_priv_subnet_1b" {
  vpc_id            = aws_vpc.terr_vpc.id
  cidr_block        = "10.1.144.0/24" #256 
  availability_zone = "eu-central-1b"

  tags = {
    Name = "terr-private-subnet-1bzone"
  }
}



#Internet gateway 
resource "aws_internet_gateway" "terr_igw" {
  vpc_id = aws_vpc.terr_vpc.id
  tags = {
    Name = "terr-internet-gateway"
  }
}

#Route table to route trafic from our subnet to internet gateway
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
#The destination for the route is 0.0.0.0/0, which represents all IPv4 addresses. 
#The target is the internet gateway that's attached to VPC.
resource "aws_route_table" "terr_rtb_public" {
  vpc_id = aws_vpc.terr_vpc.id

  #igw
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terr_igw.id
  }

  #local target
  #The default route, mapping the VPC's CIDR block to "local", 
  #is created implicitly and cannot be specified.

  tags = {
    Name = "terr-rtb-public"
  }
}

resource "aws_route_table" "terr_rtb_private" {
  vpc_id = aws_vpc.terr_vpc.id

  tags = {
    Name = "terr-rtb-private"
  }
}

#==============================================================
#Route table association
#Asociation b/w a route table and a subnet
#Provides a resource to create an association between a route 
#table and a subnet or a route table and an internet gateway or
# virtual private gateway.

#===============================================================
#1a public
resource "aws_route_table_association" "puba" {
  subnet_id      = aws_subnet.terr_pub_subnet.id
  route_table_id = aws_route_table.terr_rtb_public.id
}
#1b public
resource "aws_route_table_association" "pubb" {
  subnet_id      = aws_subnet.terr_pub_subnet_1b.id
  route_table_id = aws_route_table.terr_rtb_public.id
}

#1apriv
resource "aws_route_table_association" "priva" {
  subnet_id      = aws_subnet.terr_priv_subnet_1a.id
  route_table_id = aws_route_table.terr_rtb_private.id
}

#1bpriv
resource "aws_route_table_association" "privb" {
  subnet_id      = aws_subnet.terr_priv_subnet_1b.id
  route_table_id = aws_route_table.terr_rtb_private.id
}



# #aws_main_route_table_association
# resource "aws_default_route_table" "terr_public_assosiation" {
#   vpc_id         = aws_vpc.terr_vpc.id
#   default_route_table_id = aws_route_table.terr_rtb_public.id
# }

# #aws_main_route_table_association
# resource "aws_default_route_table" "terr_private_assosiation" {
#   vpc_id         = aws_vpc.terr_vpc.id
#   default_route_table_id = aws_route_table.terr_rtb_private.id  #route_table_id instead if aws_main_route_table_association is used
# }









