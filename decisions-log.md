# Decisions Log — Smarter Revolution Production

## Standing Approvals (Permanent)
- Docker image/cache cleanup when disk > 60% or reclaimable > 50GB
- Restart crashed production services (Tier 1)
- Clear temp files, log rotation
- SSL certificate renewal
- VACUUM ANALYZE during off-hours (midnight-5 AM EST)
- Backup verification and expired cleanup
- LOW severity security patches during off-hours
- Deploy/update monitoring scripts (no firewall/network changes)
- Block IPs with clear malicious activity
- Kill runaway processes (>90% CPU for >5 min)

## Approvals Given
| Date | Action | Approved By | Status |
|---|---|---|---|
| 2026-02-27 | Rotate OpenAI OAuth tokens | Mark | Pending |
| 2026-02-28 | Rebind staging DBs to localhost | Mark | ✅ Complete |
| 2026-02-28 | Docker disk cleanup (120GB reclaimable) | Mark (standing) | In Progress |
| 2026-02-28 | Deploy monitoring scripts to VPS | Mark (standing) | ✅ Complete |
| 2026-02-28 | Set up automated heartbeat and daily reports | Mark | ✅ Complete |

## Rejections
| Date | Action | Rejected By | Reason |
|---|---|---|---|
| (none yet) | | | |
