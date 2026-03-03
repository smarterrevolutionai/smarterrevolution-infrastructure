# System Architecture — Smarter Revolution

## Infrastructure
- **Production VPS:** 72.62.252.232 (Hostinger KVM 8: 8 vCPU, 32GB RAM, 400GB NVMe)
- **Dev/Staging VPS:** 187.77.130.210 (Hostinger KVM 4: 4 vCPU, 16GB RAM, 200GB NVMe)
- **OS:** Ubuntu 24.04 LTS
- **Reverse Proxy:** Nginx (80/443 → localhost)
- **TLS:** Nginx-managed certificates
- **DNS:** smarterrevolution.com, smarterrevolutionai.com

## Service Map

### Production Applications
| Service | Port | Stack | Managed By |
|---------|------|-------|-----------|
| CRM | 3000 | Next.js 14, Prisma, PostgreSQL 15, Redis 7, Qdrant | root PM2 |
| Command Center | 3001 | Next.js 14, PostgreSQL 16 | Docker Compose |
| Website | 3003 | Next.js 14 | root PM2 |
| Exec Dashboard | 3006 | Next.js | smarty PM2 |
| Webhook Receiver | 3005 | Node.js Express | root PM2 |
| Studio Deploy | 9001 | Node.js | root PM2 |
| Deliverables Portal | 8080 | Nginx static | Nginx |
| Infographic Server | 8085 | Nginx | Nginx |

### Data Stores
| Service | Port | Container | Binding |
|---------|------|-----------|---------|
| CRM PostgreSQL | 5432 | crm-postgres | 127.0.0.1 |
| Dashboard PostgreSQL | internal | dashboard-postgres | internal |
| Redis | 6379 | crm-redis | 127.0.0.1 |
| Qdrant | 6333 | crm-qdrant | 127.0.0.1 |
| Ollama | 11434 | crm-ollama | 127.0.0.1 |

### Agent Infrastructure
| Agent | Container | Port | Role |
|-------|-----------|------|------|
| Smarty | openclaw-kko0 | 41838 | Development |
| Optimus | openclaw-hky4 | 63586 | Production |
| Unknown | openclaw-yvmn | 59814 | Legacy? |
| Unknown | openclaw-obe4 | 54481 | Legacy? |
| Unknown | openclaw-s9hu | 46233 | Legacy? |

## Deployment Pipeline
```
Developer → push to main
    ↓
Deploy Gate (cron */5) → detect new commits
    ↓
Post to #deployment-log → await approval
    ↓
Mark: "approve <repo>" → Optimus processes
    ↓
prod-deploy.sh: backup → pull → build → health check
    ↓
Success → update state | Failure → rollback
```

## Monitoring Stack
- Health checks: every 60s (script)
- Resource monitoring: every 5m (script)
- Container monitoring: every 5m (script)
- Error aggregation: every 5m (script) → alerts every 30m
- Shadow code review: every 10m (script)
- Daily ops report: 8 AM EST → #exec-dashboard

## Backup Strategy
- CRM DB: daily pg_dump, gzipped, 14-day retention
- Pre-deploy backups: automatic before every production deploy
- Verification: daily integrity check at 4 AM EST
- DR tested: 2026-03-04 (full restore to dev VPS verified)
