CLUSTER   := phoenix
NAMESPACE := phoenix
CHART     := oci://registry-1.docker.io/arizephoenix/phoenix-helm
CHART_VER := 12.0.27

.PHONY: up down cluster secrets phoenix status

up: cluster secrets phoenix          ## build everything

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

# TODO: ingress, cert-manager, collector, netpol, test

status:
	kubectl get pods,svc,pvc,ingress -n $(NAMESPACE)

down:                                ## destroys everything, including data
	kind delete cluster --name $(CLUSTER)