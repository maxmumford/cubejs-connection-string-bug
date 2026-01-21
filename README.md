# Cube.js AggregateError with DATABASE_URL + repositoryFactory

Reproduction for a bug where `CUBEJS_DATABASE_URL` + `repositoryFactory` causes `AggregateError`.

## Bug Summary

- **Versions**: v1.5.5 and v1.6.4
- **Issue**: `repositoryFactory` + `CUBEJS_DATABASE_URL` = AggregateError on `/load`
- **Workaround**: Use explicit DB params or `driverFactory`

## Prerequisites

- [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker)
- kubectl
- curl

## Quick Start

```bash
npm test         # Creates cluster, deploys, and runs both tests
npm run cleanup  # Delete kind cluster when done
```

## Expected Results

```
=== Testing DATABASE_URL (should FAIL) ===
{"error":"Error: AggregateError"}

=== Testing explicit params (should WORK) ===
{"query":...,"data":[{"Items.count":"3"}]}
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
