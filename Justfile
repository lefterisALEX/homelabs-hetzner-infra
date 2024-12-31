# Justfile for installing Helm and kubectl
#
# Variables
hetzner_k3s_version := "2.0.9"
set dotenv-load

k8s-tools:
    @echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/

    @echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    @echo "Installation complete!"
    kubectl version --client
    helm version

print-arch:
    arch=$(uname -m); echo "Architecture: $arch"

deploy-infra:
    age --decrypt --output .env .env.enc
    terraform apply --auto-approve

hetzner-k3s:
    @echo "decrypting ssh keypair..."
    age --decrypt --output ~/.ssh/hetzner_k3s hetzner.enc
    
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

# Delete the cluster
delete:
    hetzner-k3s delete --config cluster.yaml
