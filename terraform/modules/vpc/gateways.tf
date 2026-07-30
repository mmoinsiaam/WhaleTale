resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    
    tags = {
        Component = "networking"
    }
}

resource "aws_eip" "nat" {
    domain = "vpc"
    tags = {
        Component = "networking"
    }
}

resource "aws_nat_gateway" "nat" {
    allocation_id = aws_eip.nat.id
    subnet_id     = aws_subnet.public.id
    
    depends_on = [aws_internet_gateway.igw]

    tags = {
        Component = "networking"
    }
}

