# Description

I've been working through [Let's Go by Alex Edwards](https://lets-go.alexedwards.net/), which has 
been a great resource for fundamentals in Go web development.

Building on that, I use this repository to play with various other technologies.

### kind

To spin up a kind cluster with a local registry on `localhost:5001`

```sh
chmod u+x ./scripts/kind/local-registry.sh
./scripts/kind/local-registry.sh
```

To make the images accessible from within your kind cluster:

```sh
docker tag <image>:<tag> localhost:5001/<image>:<tag>
docker push localhost:5001/<image>:<tag>
```

### ArgoCD

To install the core functionality for ArgoCD:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Currently ArgoCD has an Application synced to this repository's `kubernetes/manifests`

To visit the Web UI:

```sh
kubectl port-forward svc/argocd-server --namespace argocd 8080:80
```

Then navigate to `localhost:8080` in your web browser.

To login with credentials, the default username is `admin` and the password can be obtained from:

```
kubectl get secrets --namespace argocd argocd-initial-admin-secret --output jsonpath='{.data.password}' | base64 -d
```

