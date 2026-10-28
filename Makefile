CLUSTER   := phoenix
NAMESPACE := phoenix
CHART     := oci://registry-1.docker.io/arizephoenix/phoenix-helm
CHART_VER := 12.0.27
TRAEFIK_VER := 42.1.3
CERT_MANAGER_VER := v1.21.3

.PHONY: up down requirements cluster secrets traefik cert-manager certs phoenix status

up: requirements cluster secrets traefik cert-manager certs phoenix  ## build everything

requirements:                        ## create venv and install requirements.txt (no activate: each recipe line is its own shell)
	python3.13 -m venv venv
	venv/bin/python -m pip install -r requirements.txt

cluster:                             ## create the kind cluster if it doesn't exist
	@kind get clusters | grep -qx $(CLUSTER) || kind create cluster --config kind-config.yaml
	kubectl config use-context kind-$(CLUSTER)

secrets:                             ## create the DB secret once; never overwrite it
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl get secret phoenix-db -n $(NAMESPACE) >/dev/null 2>&1 || \
	kubectl create secret generic phoenix-db -n $(NAMESPACE) \
	  --from-literal=POSTGRES_PASSWORD="$$(openssl rand -base64 24)" \
	  --from-literal=POSTGRES_DB=phoenix \
	  --from-literal=USERDB_USER=phoenix \
	  --from-literal=USERDB_PASSWORD="$$(openssl rand -base64 24)"

phoenix:                             ## install or upgrade Phoenix
	helm upgrade --install phoenix $(CHART) --version $(CHART_VER) \
	  -n $(NAMESPACE) -f values/phoenix.yaml --wait

traefik:                             ## install or upgrade the Traefik ingress controller
	helm repo add traefik https://traefik.github.io/charts --force-update
	helm upgrade --install traefik traefik/traefik --version $(TRAEFIK_VER) \
	  -n traefik --create-namespace -f values/traefik.yaml --wait

cert-manager:                        ## install or upgrade cert-manager (with CRDs)
	helm repo add jetstack https://charts.jetstack.io --force-update
	helm upgrade --install cert-manager jetstack/cert-manager --version $(CERT_MANAGER_VER) \
	  -n cert-manager --create-namespace --set crds.enabled=true --wait

certs:                               ## private CA + Phoenix leaf cert; exports ca.crt for clients
	kubectl apply -f certs/ca.yaml
	kubectl wait --for=condition=Ready certificate/root-ca -n cert-manager --timeout=60s
	kubectl wait --for=condition=Ready certificate/phoenix-tls -n $(NAMESPACE) --timeout=60s
	kubectl get secret root-ca -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d > certs/ca.crt

# TODO: collector, netpol, test

status:
	kubectl get pods,svc,pvc,ingress -n $(NAMESPACE)
	kubectl get pods,svc -n traefik
	kubectl get clusterissuers; kubectl get certificates -A

down:                                ## destroys everything, including data
	kind delete cluster --name $(CLUSTER)