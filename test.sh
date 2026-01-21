#!/bin/bash
set -e

echo "=== Cleaning up any existing cluster ==="
kind delete cluster --name cube-test 2>/dev/null || true

echo "=== Creating kind cluster ==="
kind create cluster --name cube-test --config kind-config.yaml

echo "=== Waiting for default service account ==="
sleep 10

echo "=== Deploying PostgreSQL and schema server ==="
kubectl apply -f postgres.yaml -f schema-server.yaml
kubectl wait --for=condition=Ready pod/postgres pod/schema-server --timeout=120s

echo "=== Deploying Cube.js with DATABASE_URL ==="
kubectl apply -f repro-database-url.yaml
kubectl wait --for=condition=Ready pod/cube-database-url --timeout=180s

echo "=== Deploying Cube.js with explicit params ==="
kubectl apply -f repro-explicit-params.yaml
kubectl wait --for=condition=Ready pod/cube-explicit-params --timeout=180s

echo "=== Setting up port forwards ==="
pkill -f 'port-forward' 2>/dev/null || true
kubectl port-forward svc/cube-database-url 4002:4000 > /dev/null 2>&1 &
kubectl port-forward svc/cube-explicit-params 4003:4000 > /dev/null 2>&1 &
sleep 5

echo ""
echo "=========================================="
echo "=== Testing DATABASE_URL (should FAIL) ==="
echo "=========================================="
curl -s 'http://localhost:4002/cubejs-api/v1/load?query=%7B%22measures%22%3A%5B%22Items.count%22%5D%7D' -H 'Authorization: test-secret'
echo ""

echo ""
echo "=============================================="
echo "=== Testing explicit params (should WORK) ==="
echo "=============================================="
curl -s 'http://localhost:4003/cubejs-api/v1/load?query=%7B%22measures%22%3A%5B%22Items.count%22%5D%7D' -H 'Authorization: test-secret'
echo ""

echo ""
echo "=== Cleaning up port forwards ==="
pkill -f 'port-forward' 2>/dev/null || true

echo ""
echo "=== Done! Run 'kind delete cluster --name cube-test' to clean up ==="
