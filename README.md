# phoenix
ports in use:
8080 --> http ingress
8443 --> https ingress
4318 --> otlp collector's nodeport

The ingress address displays as empty which is to be expected ith a ClusterIP Service, there is no external address for Traefik to report.

find phoenix at http://phoenix.localhost:8080