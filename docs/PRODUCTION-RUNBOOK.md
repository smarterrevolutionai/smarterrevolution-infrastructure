# Production Runbook — Smarter Revolution

## Quick Reference

| Service | Port | Process | Health Check |
|---------|------|---------|-------------|
| CRM | 3000 | root PM2 `smarter-crm` | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` → 307 |
| Command Center | 3001 | Docker `openclaw-dashboard` | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3001` → 307 |
| Website | 3003 | root PM2 `smarterrevolutionai` | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3003` → 200 |
| Exec Dashboard | 3006 | smarty PM2 `openclaw-exec-dashboard` | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3006` → 200 |
| Webhook Receiver | 3005 | root PM2 `webhook-receiver` | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3005` → 200 |
| CRM PostgreSQL | 5432 | Docker `crm-postgres` | `docker exec crm-postgres pg_isready -U crm_user` |
| Dashboard PostgreSQL | (internal) | Docker `dashboard-postgres` | `docker exec dashboard-postgres pg_isready -U dashboard_user` |
| Redis | 6379 | Docker `crm-redis` | `docker exec crm-redis redis-cli ping` |
| Qdrant | 6333 | Docker `crm-qdrant` | `curl http://localhost:6333/healthz` |
| Nginx | 80/443 | systemd `nginx` | `curl -I https://smarterrevolution.com` |

## SSH Access
```bash
ssh -i ~/.ssh/id_ed25519_vps -p 2222 smarty@72.62.252.232
```
- Only Optimus agent + Hostinger keys have access
- Root login disabled, password auth disabled

## Deploy Process
1. Developer pushes to `main` branch
2. Deploy Gate (cron */5) detects new commits → posts to #deployment-log
3. Mark types `approve <repo>` in #deployment-log
4. Optimus runs `approve-deploy.sh` + `prod-deploy.sh`
5. Automated: backup → pull → build → health check → rollback if failed
6. Results posted to #deployment-log

### Manual Deploy (Emergency)
```bash
cd /opt/smarterrevolution-infrastructure/scripts
./approve-deploy.sh <repo>
./prod-deploy.sh <repo>
```

## Restart Procedures

### CRM (root PM2)
```bash
sudo pm2 restart smarter-crm
sudo pm2 logs smarter-crm --lines 20
```

### Command Center (Docker)
```bash
cd /opt/openclaw-command-center
docker compose restart openclaw-dashboard
docker logs openclaw-dashboard --tail 20
```

### Website (root PM2)
```bash
sudo pm2 restart smarterrevolutionai
```

### Full System Restart
```bash
# 1. Stop apps
sudo pm2 stop all
docker stop $(docker ps -q)

# 2. Start infrastructure
cd /opt/smarter-crm && docker compose up -d  # postgres, redis, qdrant
cd /opt/openclaw-command-center && docker compose up -d  # dashboard + db

# 3. Start apps
sudo pm2 start all

# 4. Verify
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000  # 307
curl -s -o /dev/null -w "%{http_code}" http://localhost:3001  # 307
curl -s -o /dev/null -w "%{http_code}" http://localhost:3003  # 200
```

## Backup & Restore

### Daily Backups (automated via cron)
- CRM DB: `/opt/backups/` (gzipped pg_dump)
- Verification: daily at 4 AM EST

### Manual Backup
```bash
docker exec -e PGPASSWORD=eZKIAjAidWgmwHgJcSow2m08cC9YCdjy crm-postgres \
  pg_dump -U crm_user crm_db | gzip > /opt/backups/manual-$(date +%Y%m%d-%H%M%S).sql.gz
```

### Restore to Dev VPS
```bash
# From production VPS
scp -P 2222 /opt/backups/BACKUP_FILE.sql.gz smarty@187.77.130.210:/tmp/

# On dev VPS
gunzip -c /tmp/BACKUP_FILE.sql.gz | docker exec -i crm-postgres psql -U crm_user -d crm_db
```

## Incident Response

### Service Down
1. Check: `curl -s -o /dev/null -w "%{http_code}" http://localhost:<PORT>`
2. Check logs: `sudo pm2 logs <name> --lines 50` or `docker logs <container> --tail 50`
3. Restart: See restart procedures above
4. If persists: Check disk (`df -h`), memory (`free -h`), ports (`ss -tlnp | grep <PORT>`)

### Database Issues
1. Check: `docker exec crm-postgres pg_isready -U crm_user -d crm_db`
2. Connections: `docker exec crm-postgres psql -U crm_user -d crm_db -c "SELECT count(*) FROM pg_stat_activity;"`
3. Slow queries: `docker exec crm-postgres psql -U crm_user -d crm_db -c "SELECT * FROM pg_stat_activity WHERE state = active AND duration > interval 5 seconds;"`

### Disk Full
1. Check: `df -h /` and `du -sh /opt/* | sort -h`
2. Clean Docker: `docker system prune -f`
3. Clean old backups: `find /opt/backups -mtime +14 -delete`
4. Clean PM2 logs: `pm2 flush`

## Monitoring
- Health check: cron every 60s → `/opt/smarterrevolution-infrastructure/logs/health-check-cron.log`
- Resources: cron every 5m → `/opt/smarterrevolution-infrastructure/logs/resource-cron.log`
- Containers: cron every 5m → `/opt/smarterrevolution-infrastructure/logs/container-cron.log`
- Error tracker: cron every 5m → aggregated errors
- Alerts: every 30m → #alerts-critical (Discord)

## Firewall (UFW)
- Default: deny incoming
- Allowed: 80, 443, 2222 (SSH), 3000-3006, 8080, 8085
- Blocked: 5432, 5433, 5442, 5452 (databases)
- Docker ports bypass UFW — always bind to 127.0.0.1 in docker-compose

## Key Contacts
- Mark Alouf (Technical Lead): mark@smarterrevolution.com
- Optimus (Production Agent): #deployment-log, #exec-dashboard
- Smarty (Dev Agent): #smarty-optimus
