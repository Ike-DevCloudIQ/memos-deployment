# Memos Deployment: DevOps Learning Journey 🚀

A complete, production-grade deployment of **Memos** (self-hosted note-taking app) to AWS EKS with GitOps.

**This project teaches DevOps by doing**, progressing from containerization → infrastructure → Kubernetes → GitOps → CI/CD → monitoring.

---

## 🎓 Learning Path (6 Stages)

| Stage | Topic | Status | Duration |
|-------|-------|--------|----------|
| 1 | **The Application** - Docker & Containerization | ▶️ In Progress | 1-2 days |
| 2 | **Terraform** - Infrastructure as Code | ⏳ Next | 2-3 days |
| 3 | **Kubernetes** - Container Orchestration | ⏳ Coming | 2-3 days |
| 4 | **ArgoCD** - GitOps Automation | ⏳ Coming | 1-2 days |
| 5 | **GitHub Actions** - CI/CD Pipelines | ⏳ Coming | 1-2 days |
| 6 | **Monitoring** - Prometheus + Grafana | ⏳ Coming | 1-2 days |

**Total**: ~10-15 days to production-grade deployment!

---

## 📖 Quick Links

- **[LEARNING_GUIDE.md](LEARNING_GUIDE.md)** - High-level learning path
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design & components
- **[Stage 1: The App](docs/STAGE1_APP.md)** - Detailed containerization guide

---

## 🚀 Quick Start (Stage 1: Local Docker)

### Prerequisites
- Docker Desktop installed
- git configured
- 4GB RAM available

### Run Locally
```bash
# Clone this repository
git clone https://github.com/Ike-DevCloudIQ/memos-deployment.git
cd memos-deployment

# Start the app locally with Docker
docker-compose -f app/docker-compose.yaml up -d

# Wait 30 seconds for database to initialize
sleep 30

# Open browser
open http://localhost:5230
```

### Stop
```bash
docker-compose -f app/docker-compose.yaml down
```

---

## 📁 Repository Structure

```
memos-deployment/
├── README.md                          # This file
├── LEARNING_GUIDE.md                  # Learning path overview
├── docs/
│   ├── ARCHITECTURE.md               # System design
│   ├── STAGE1_APP.md                 # Stage 1 detailed guide
│   ├── STAGE2_TERRAFORM.md           # (coming in Stage 2)
│   └── ...
├── app/
│   ├── Dockerfile                    # Multi-stage Docker build
│   └── docker-compose.yaml           # Local dev setup
├── terraform/                         # (Stage 2)
│   ├── bootstrap/                    # AWS account bootstrap
│   ├── modules/                      # Reusable IaC modules
│   └── main.tf                       # Main infrastructure
├── k8s/                              # (Stage 3)
│   ├── deployments/
│   ├── services/
│   └── configmaps/
├── argocd/                           # (Stage 4)
├── .github/workflows/                # (Stage 5)
└── .gitignore
```

---

## 🎯 Stage 1: The Application

### What You'll Learn
✅ Docker concepts (images, containers, registries)
✅ Write production-grade Dockerfile with multi-stage builds
✅ docker-compose for local multi-container setup
✅ Application architecture and dependencies
✅ Security best practices (non-root user, healthchecks)

### Tasks
1. Clone Memos source and understand architecture
2. Create Dockerfile with multi-stage build
3. Create docker-compose.yaml
4. Run locally and test
5. Document everything

### Success Criteria
- [ ] App accessible at http://localhost:5230
- [ ] Can create notes and they persist
- [ ] Docker image builds successfully
- [ ] Database healthcheck passes
- [ ] All files committed to git

**→ [Start Stage 1](docs/STAGE1_APP.md)**

---

## 👤 Project Owner

- **Name**: Ike-DevCloudIQ
- **Email**: ikennaubah2@yahoo.com
- **GitHub**: [@Ike-DevCloudIQ](https://github.com/Ike-DevCloudIQ)

---

## 📚 Resources

### Docker
- [Docker Official Docs](https://docs.docker.com/)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Kubernetes
- [Kubernetes Fundamentals](https://kubernetes.io/docs/concepts/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### Terraform
- [Terraform Docs](https://www.terraform.io/docs)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

### ArgoCD
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

### GitHub Actions
- [Actions Documentation](https://docs.github.com/en/actions)

### Monitoring
- [Prometheus](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/)

---

## 📝 License

Open source - feel free to fork and use for your own projects!

---

## 🤝 Contributing

This is a learning project. To contribute:
1. Fork the repo
2. Create a branch (`git checkout -b feature/your-feature`)
3. Commit changes (`git commit -am 'Add feature'`)
4. Push (`git push origin feature/your-feature`)
5. Create Pull Request

---

## ❓ Questions?

Feel free to open an issue or reach out via email.

**Happy learning! 🎓**
