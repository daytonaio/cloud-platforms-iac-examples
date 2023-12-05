# gcp-example

In order to deploy GKE cluster with Daytona follow these steps:

1. Adjust values to your environment in `config.yaml`
2. First run terraform in `tf-1-gke` folder:
```
cd tf-1-gke
terraform apply
```
3. Once finished move into `tf-2-k8s` folder:
```
cd tf-2-k8s
terraform apply
```
4. Daytona application will be available on your domain you set in `config.yaml`
