argocd-server-fwd:
    @echo "Forwarding port 8080 to ArgoCD server"
    @echo "Access ArgoCD at https://localhost:8080"
    @echo "Username: admin"
    @echo "Password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode)"
    @kubectl port-forward svc/argocd-server -n argocd 8080:80