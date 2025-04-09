# N8N Helm Chart project

## Project Goals
- Configure a N8N Helm chart that emphasizes incremental development and fast feedback loops
- The Helm chart has optional dependencies to external Postgres chart (cloudnative-pg/cloudnative-pg) and Traefik Ingress (traefik/traefik)

## Techstacks
- **helmfile**: v0.171.0 for orchestrating multiple charts installation
- **just**: 1.40.0 command runner to automate repetitive tasks

## Architecture & Folder Structure

### Project Structure

```
.
├── charts                  # all charts here
│   ├── helmfile.yaml       # helmfile
│   ├── justfile            # justfile to automate tasks
│   ├── n8n                 # local n8n chart
│   └── values              # value folders    
├── docs                    # docs folder
│   └── workflow.md
└── memory_bank             # memory bank folder
    └── long_term.md
```