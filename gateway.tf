// configure the aws

provider "aws" {
region = "ap-south-1"
profile = "linux"
}

//creating your  vpc

resource "aws_vpc" "Vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Vpc"
  }
enable_dns_hostnames = true 
}

//creating two subnets  out of these two subnet one is private and another is public 

resource "aws_subnet" "PublicSubnet" {
  depends_on = [ aws_vpc.Vpc , ] 
  vpc_id     = "${aws_vpc.Vpc.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone_id = "aps1-az1"

  tags = {
    Name = "PublicSubnet"
  }
map_public_ip_on_launch=true
}


resource "aws_subnet" "PrivateSubnet" {
  depends_on = [ aws_vpc.Vpc , ] 
  vpc_id     = "${aws_vpc.Vpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone_id = "aps1-az1"

  tags = {
    Name = "PrivateSubnet"
  }
}


//creating a gateway 

resource "aws_internet_gateway" "Mygateway" {

  depends_on = [ aws_vpc.Vpc , ] 
  vpc_id = "${aws_vpc.Vpc.id}"

tags = {
    Name = "Mygateway"
  }
}


//creating a Route Table

resource "aws_route_table" "RouteTable" {
  depends_on = [ aws_vpc.Vpc ,aws_internet_gateway.Mygateway,   ] 
  vpc_id = "${aws_vpc.Vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.Mygateway.id}"
  }


  tags = {
    Name = "RouteTable"
  }
}

//Route table assocation with public subnet

resource "aws_route_table_association" "publicAssociation" {
  depends_on= [aws_subnet.PublicSubnet , aws_route_table.RouteTable , ]
  subnet_id  = aws_subnet.PublicSubnet.id 
  route_table_id = aws_route_table.RouteTable.id

}

//creating first security group to provide accessing for All Security Group


resource "aws_security_group" "FirstSecurity" {
  depends_on = [ aws_vpc.Vpc, ]
  name        = "allow_http"
  description = "Allow http ,ssh and icmp inbound traffic"
  vpc_id      = "${aws_vpc.Vpc.id}"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "icmp"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FirstSecurity"
  }
}


//creating SecondSecurity for allowing particular Security Group 

resource "aws_security_group" "SecondSecurity" {
  name        = "SecondSecurity" 
  description = "Allow FirstSecurity only"
  vpc_id      = "${aws_vpc.Vpc.id}"
  
  ingress {
    description = "MySql"
    security_groups = ["${aws_security_group.FirstSecurity.id }"]
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  

  tags = {
    Name = "SecondSecurity"
  }
}


//creating ThirdSecurityGroup for BastionHost Instance 

resource "aws_security_group" "ThirdSecurity" {
  name        = "ThirdSecurity" 
  description = "Allow ssh only"
  vpc_id      = "${aws_vpc.Vpc.id}"

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ThirdSecurity"
  }
} 

//creating FourthSecurity for allow ssh in MySql 

resource "aws_security_group" "FourthSecurity" {
  name        = "FourthSecurity" 
  description = "Allow ThirdSecurity only "
  vpc_id      = "${aws_vpc.Vpc.id}"

  ingress {
    description = "ssh"
    security_groups = ["${aws_security_group.ThirdSecurity.id}"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FourthSecurity"
  }
}

//creating WordPress instance 


resource "aws_instance" "MyWordPress" {
  depends_on = [ aws_security_group.FirstSecurity , ]
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  associate_public_ip_address=true
  key_name = "MyKey"
  
  vpc_security_group_ids = ["${ aws_security_group.FirstSecurity.id}"]
  subnet_id = "${aws_subnet.PublicSubnet.id}"
  

  tags = {
    Name = "MyWordPress"
  }
}

//creating  MySQL instance 

resource "aws_instance" "MySql" {
  depends_on = [ aws_security_group.SecondSecurity , ]
  ami           = "ami-0019ac6129392a0f2"
  instance_type = "t2.micro"
  key_name = "MyKey"
  vpc_security_group_ids = ["${ aws_security_group.SecondSecurity.id}"]
  subnet_id = "${aws_subnet.PrivateSubnet.id}"
  

  tags = {
    Name = "MySql"
  }
}


//creating bastionHost instance 


resource "aws_instance" "bastionHost" {
  depends_on = [ aws_security_group.ThirdSecurity , ]
  ami           = "ami-0019ac6129392a0f2"
  instance_type = "t2.micro"
  associate_public_ip_address=true
  key_name = "MyKey"
  vpc_security_group_ids = ["${ aws_security_group.ThirdSecurity.id}"]
  subnet_id = aws_subnet.PublicSubnet.id
  

  tags = {
    Name = "bastionHost"
  }
}

//creating eip
resource "aws_eip" "EIP" {
 vpc = true
 depends_on = [aws_internet_gateway.Mygateway ,]
 instance = "${aws_instance.MySql.id}"
}

//creating natgateway

resource "aws_nat_gateway" "NatGateWay" {
 
  allocation_id = "${aws_eip.EIP.id}"
  subnet_id     = "${aws_subnet.PublicSubnet.id}"
   depends_on = ["aws_internet_gateway.Mygateway"]
  

  tags = {
    Name = "NatGateWay"
  }
}

resource "aws_route_table" "Table2" {
  vpc_id = "${aws_vpc.Vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NatGateWay.id}"
  }
 tags = {
    Name = "Table2"
  }
}

resource "aws_route_table_association" "associate" {
  subnet_id      = aws_subnet.PrivateSubnet.id
  route_table_id = aws_route_table.Table2.id
}
