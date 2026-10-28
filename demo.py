from phoenix.otel import register
import anthropic

# Sends traces to PHOENIX_COLLECTOR_ENDPOINT (Traefik ingress, HTTP only) and auto-instruments
# the Anthropic SDK. Without protocol="http/protobuf", phoenix.otel assumes gRPC and swaps the port to 4317.
register(project_name="interview-demo", auto_instrument=True, protocol="http/protobuf")

client = anthropic.Anthropic()

questions = [
    "What is a Kubernetes PVC? Two sentences.",
    "Explain Helm in one sentence.",
    "What are the main challenges of an air-gapped Kubernetes install?",
]

for q in questions:
    r = client.messages.create(
        model="claude-opus-5-5",
        max_tokens=16000,
        messages=[{"role": "user", "content": q}],
    )
    # The response can include a thinking block before the answer, so pick out the text
    answer = next(b.text for b in r.content if b.type == "text")
    print(f"Q: {q}\nA: {answer}\n")