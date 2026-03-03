# Security Baseline — Production VPS

## Last Audit: 2026-03-04

### Access Control
- SSH: Port 2222, key-only, PermitRootLogin=no
- Authorized keys: 9 (Optimus + Hostinger + OpenClaw nodes)
- Development agents: NO production SSH access (removed 2026-03-04)
- Sudo: smarty user via sudo group

### Network
- UFW: deny-by-default, explicit allowlist
- Docker: all DB containers bound to 127.0.0.1
- Nginx: reverse proxy for 80/443 → localhost services
- TLS: managed by Nginx (smarterrevolution.com, dashboard.smarterrevolutionai.com)

### Data Protection
- DB passwords: centralized in /opt/secrets/ (perms 700/600)
- .env files: all 600 permissions
- Backups: daily pg_dump, 14-day retention, verified daily
- DR tested: 2026-03-04 (successful restore to dev VPS)

### Known Risks (Accepted)
- Docker socket grants root-equivalent access to docker group members
- All PM2 apps run as root (migration to non-root is planned)
- 5 OpenClaw gateway processes consuming ~3GB (orphan cleanup needed)

### Remediated (2026-03-04)
- C1: PostgreSQL 5432 was publicly exposed → rebound to 127.0.0.1
- C2: UFW "Anywhere on eth0" rule was bypassing firewall → deleted
- C3: 14 SSH keys (5 agent keys removed) → 9 keys
- H4: Port 22 open but unused → rule deleted
