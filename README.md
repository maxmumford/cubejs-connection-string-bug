# Cube.js AggregateError with DATABASE_URL + repositoryFactory

Reproduction for a bug where `CUBEJS_DATABASE_URL` + `repositoryFactory` causes `AggregateError`.

## Bug Summary

- **Versions**: v1.5.5 and v1.6.4
- **Issue**: `repositoryFactory` + `CUBEJS_DATABASE_URL` = AggregateError on `/load`
- **Workaround**: Use explicit DB params or `driverFactory`

## Quick Start

```bash
npm run setup    # Create kind cluster and deploy postgres/schema-server
npm test         # Run both tests and compare results
npm run cleanup  # Delete kind cluster
```

## Expected Results

```
=== Testing DATABASE_URL (should FAIL) ===
{"error":"Error: AggregateError"}

=== Testing explicit params (should WORK) ===
{"data":[{"Items.count":"3"}]}
```

## Manual Steps

```bash
# 1. Create kind cluster
kind create cluster --name cube-test --config kind-config.yaml

# 2. Deploy stack
kubectl apply -f postgres.yaml -f schema-server.yaml
kubectl wait --for=condition=Ready pod/postgres pod/schema-server --timeout=60s

# 3. Test with DATABASE_URL (FAILS)
kubectl apply -f repro-database-url.yaml
kubectl wait --for=condition=Ready pod/cube-database-url --timeout=120s
kubectl port-forward svc/cube-database-url 4000:4000 &
curl -s "http://localhost:4000/cubejs-api/v1/load?query=%7B%22measures%22%3A%5B%22Items.count%22%5D%7D" -H "Authorization: test-secret"

# 4. Test with explicit params (WORKS)
kubectl apply -f repro-explicit-params.yaml
kubectl wait --for=condition=Ready pod/cube-explicit-params --timeout=120s
kubectl port-forward svc/cube-explicit-params 4001:4000 &
curl -s "http://localhost:4001/cubejs-api/v1/load?query=%7B%22measures%22%3A%5B%22Items.count%22%5D%7D" -H "Authorization: test-secret"
```

## Workaround

```javascript
const dbUrl = new URL(process.env.CUBEJS_DATABASE_URL);

module.exports = {
  driverFactory: () => ({
    type: 'postgres',
    host: dbUrl.hostname,
    port: parseInt(dbUrl.port) || 5432,
    database: dbUrl.pathname.slice(1),
    user: decodeURIComponent(dbUrl.username),
    password: decodeURIComponent(dbUrl.password),
  }),
  repositoryFactory: () => ({ dataSchemaFiles: async () => fetchSchemasFromHttp() }),
};
```

## Notes

- Issue does NOT occur without `repositoryFactory` (file-based schemas work)
- Issue does NOT occur with explicit DB params
- `/meta` endpoint works, only `/load` fails
