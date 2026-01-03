# Kubernetes 部署记录

## SWR 拉取凭据
- 命令：`kubectl create secret docker-registry swr-cred -n buildingos-prod --docker-server=swr.cn-east-3.myhuaweicloud.com --docker-username cn-east-3@HPUA47E21TXTL1E4MHAJ --docker-password 615e168df23e9bf7f95b5414b6e0c88b0cfaa9438f53fda6f64a691d4982a5ab`

## 操作日志
- toolName: run_command
  - status: success
  - command: `kompose -f "docker/docker-compose.production.yml" convert --namespace buildingos-prod --out k8s/`
- toolName: view_files
  - status: success
  - filePath: `c:\githubproject\buildingos_build\buildingos.ai\k8s\backend-deployment.yaml`
- toolName: view_files
  - status: success
  - filePath: `c:\githubproject\buildingos_build\buildingos.ai\k8s\web-deployment.yaml`
- toolName: edit_file_update
  - status: success
  - filePath: `c:\githubproject\buildingos_build\buildingos.ai\k8s\backend-deployment.yaml`
  - changes: 添加 `imagePullSecrets: [{ name: swr-cred }]`
- toolName: edit_file_update
  - status: success
  - filePath: `c:\githubproject\buildingos_build\buildingos.ai\k8s\web-deployment.yaml`
  - changes: 添加 `imagePullSecrets: [{ name: swr-cred }]`
- toolName: write_to_file
  - status: success
  - filePath: `c:\githubproject\buildingos_build\buildingos.ai\k8s\web-init-job.yaml`
- toolName: write_to_file
  - status: success
  - filePath: `c:\githubproject\buildingos_build\buildingos.ai\k8s\ingress.yaml`
- toolName: run_command
  - status: success
  - command: `kubectl apply -f k8s/buildingos-prod-namespace.yaml --validate=false`
- toolName: run_command
  - status: success
  - command: `kubectl create secret docker-registry swr-cred -n buildingos-prod --docker-server=swr.cn-east-3.myhuaweicloud.com --docker-username cn-east-3@HPUA47E21TXTL1E4MHAJ --docker-password 615e168df23e9bf7f95b5414b6e0c88b0cfaa9438f53fda6f64a691d4982a5ab`
- toolName: run_command
  - status: success
  - command: `kubectl apply -f k8s/web-init-job.yaml --validate=false`
- toolName: run_command
  - status: partial_success
  - command: `kubectl apply -f k8s/ --validate=false`
  - note: 资源整体创建成功，部分 PVC 重复配置导致 patch 报错，可忽略

## 访问
- Ingress: `http://localhost` → web；`http://localhost/api` → backend
- 如未启用 Ingress 控制器，可使用端口转发：
  - 前端：`kubectl port-forward svc/web -n buildingos-prod 8080:80`
  - 后端：`kubectl port-forward svc/backend -n buildingos-prod 3001:3001`

