## Summary

Module 1 — Deploy Ollama Chat on AWS (Code Platoon AI & Cloud Ops).

- [ ] Infrastructure: VPC, NAT, ALB, ASGs, SGs, NACLs (Terraform or `deploy-aws.sh`)
- [ ] GHCR images pushed (`ollama-chat-backend`, `ollama-chat-frontend` with `VITE_API_URL`)
- [ ] [docs/SUBMISSION.md](../docs/SUBMISSION.md) deployment evidence table filled
- [ ] Screenshots attached per [docs/SCREENSHOTS.md](../docs/SCREENSHOTS.md)

## Test plan

```bash
export ALB_DNS=<alb-dns-name>
./infrastructure/scripts/verify-deployment.sh
```

- [ ] ALB target groups healthy (Flask + React)
- [ ] Browser chat at `http://${ALB_DNS}/`
- [ ] Flask not directly reachable from internet on :5000

## Deployment notes

| Field | Value |
|-------|-------|
| ALB DNS | |
| Region | |
| Demo URL | |
