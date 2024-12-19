# Development notes

## Develop the Helm chart

```bash
helm create app
```

- Test with

```bash
helm template foo ./app
helm install foo ./app --dry-run
```
