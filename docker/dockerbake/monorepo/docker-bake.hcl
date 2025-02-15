group "default" {
  targets = ["frontend", "backend"]
}

target "frontend" {
  context = "./frontend"
  dockerfile = "frontend.Dockerfile"
  args = {
    NODE_VERSION = "20"
  }
  tags = ["366140438193.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest"]
}

target "backend" {
  context = "./backend"
  dockerfile = "backend.Dockerfile"
  args = {
    GO_VERSION = "1.21"
  }
  tags = ["366140438193.dkr.ecr.ap-south-1.amazonaws.com/backend:latest"]
}