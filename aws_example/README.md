In order to deploy EKS cluster with Daytona follow these steps:

1. Rename `config.yaml.example` into `config.yaml`
2. Adjust values to your environment in `config.yaml`
3. First run terraform in `tf-1-eks` folder:
```
cd tf-1-eks
terraform apply
```
4. Once finished move into `tf-2-k8s` folder:
```
cd tf-2-k8s
terraform apply
```
5. Daytona application will be available on your domain you set in `config.yaml`
