# Justfile for installing Helm and kubectl
#
# Variables
hetzner_k3s_version := "2.0.9"
set dotenv-load


# decrypt the .env file and the private key for the cluster nodes.
decrypt:
    age --decrypt --output .env .env.enc
    age --decrypt --output ~/.ssh/hetzner_k3s hetzner.enc
    cp hetzner.pub ~/.ssh/hetzner_k3s.pub
    chmod 400 ~/.ssh/hetzner_k3s

# deploy the NAT gateway and private network in Hetzner
deploy-infra:
    terraform apply --auto-approve

# installs all required tools to deploy the cluster
k8s-tools:
    @echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/

    @echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
 
    @echo "Installing age..."
    apt install age

    @echo "Installing argo cli..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64

    @echo "Installing kubeseal."
    KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    wget https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION#v}-linux-amd64.tar.gz
    tar -xvzf kubeseal-${KUBESEAL_VERSION#v}-linux-amd64.tar.gz kubeseal
    chmod +x kubeseal
    sudo mv kubeseal /usr/local/bin/
    rm kubeseal-${KUBESEAL_VERSION#v}-linux-amd64.tar.gz

    @echo "Installation complete!"
    kubectl version --client
    helm version



# deploy the k3s cluster
create-cluster:
    @echo "Installing hetzner-k3s..."
    arch=$(uname -m);  \
    if [ $arch = "x86_64" ]; then \
        wget https://github.com/vitobotta/hetzner-k3s/releases/download/v{{hetzner_k3s_version}}/hetzner-k3s-linux-amd64; \
        chmod +x hetzner-k3s-linux-amd64; \
        sudo mv hetzner-k3s-linux-amd64 /usr/local/bin/hetzner-k3s; \
    elif [ $arch = "aarch64" ]; then \
        wget https://github.com/vitobotta/hetzner-k3s/releases/download/v{{hetzner_k3s_version}}/hetzner-k3s-linux-arm64; \
        chmod +x hetzner-k3s-linux-arm64; \
        sudo mv hetzner-k3s-linux-arm64 /usr/local/bin/hetzner-k3s; \
    else \
        echo "Unsupported architecture: $arch"; \
        exit 1; \
    fi

    @echo "Deploy k3s cluster"
    hetzner-k3s create --config cluster.yaml | tee create.log

    @echo "installs argocd and tailscale"
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update

    helm upgrade --install argo-cd --namespace argocd  --create-namespace argo/argo-cd -f charts/argocd/values.yaml
    kubectl create secret generic universal-auth-credentials -n kube-system --from-literal=clientId=$INFISICAL_ID --from-literal=clientSecret=$INFISICAL_SECRET -oyaml | kubectl apply -f -

# install tailscale
tailscale:
    helm repo add tailscale https://pkgs.tailscale.com/helmcharts
    helm repo update
    helm upgrade \
           --install \
           tailscale-operator \
           tailscale/tailscale-operator \
           --namespace=tailscale \
           --create-namespace \
           --set-string oauth.clientId="${TS_CLIENT_ID}" \
           --set-string oauth.clientSecret="${TS_CLIENT_SECRET}" \
           --wait

# bootstrap apps
bootstrap-apps:
    @echo "bootstrap all apps"
    kubectl apply -f apps/bootstrap.yaml

# Delete the cluster
delete-cluster:
    hetzner-k3s delete --config cluster.yaml

# destroy all infra
destroy-infra:
    terraform destroy --auto-approve
