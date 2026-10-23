# Mini-projet Jenkins CI/CD — PayMyBuddy

Pipeline Jenkins pour l’application Spring Boot [PayMyBuddy](https://github.com/alvirranyadja/PayMyBuddy), avec agents Docker, SonarCloud, Docker Hub, déploiement SSH staging/prod et notification Slack.

## Prérequis (déjà préparés)

| Élément | Valeur |
|---------|--------|
| Jenkins | `http://<IP_EC2_JENKINS>:8080` |
| Staging | `56.228.41.32:8080` |
| Prod | `13.60.222.9:8080` |
| Docker Hub | `alvirra/paymybuddy` |
| SonarCloud | org/key `alvirranyadja` |
| Credentials | `dockerhub-credentials`, `ssh-deploy`, `sonar-token`, `slack-webhook` |

## Structure

```text
mini-projet-jenkins/
├── Jenkinsfile                 # Pipeline CI/CD
├── Dockerfile                  # Multi-stage Maven + Corretto 17
├── deploy/docker-compose.yml   # App + MySQL sur staging/prod
├── scripts/validate.sh
├── sonar-project.properties
├── pom.xml / src/              # Code PayMyBuddy
└── README.md
```

## Stages de la pipeline

| Stage | Agent Docker | Branches |
|-------|--------------|----------|
| Tests Automatisés | `maven:3.9-eclipse-temurin-17` | toutes |
| Qualité SonarCloud | maven | toutes |
| Quality Gate | any | toutes |
| Compilation JAR | maven | toutes |
| Build & Push DockerHub | `docker:27` | toutes |
| Staging + Validation | alpine | **main** seulement |
| Production + Validation | alpine (+ input manuel) | **main** seulement |
| Slack (post) | webhook | toujours |

## Pousser le code sur GitHub

Depuis ce dossier :

```bash
cd mini-projet-jenkins
git remote -v
# doit pointer vers https://github.com/alvirranyadja/PayMyBuddy.git

git add Jenkinsfile Dockerfile deploy scripts sonar-project.properties README.md
git commit -m "feat: pipeline Jenkins CI/CD complète"
git push origin main
```

## Créer le job Jenkins

1. Jenkins → **New Item**
2. Nom : `paymybuddy-cicd`
3. Type : **Pipeline**
4. Pipeline → Definition : **Pipeline script from SCM**
5. SCM : **Git**
6. Repository URL : `https://github.com/alvirranyadja/PayMyBuddy.git`
7. Branch : `*/main`
8. Script Path : `Jenkinsfile`
9. **Save** → **Build Now**

## URLs après déploiement

- Staging : http://56.228.41.32:8080  
- Prod : http://13.60.222.9:8080  

## Notes

- Si le stage Docker échoue (`permission denied` sur docker.sock), sur le serveur Jenkins :
  ```bash
  sudo docker exec -u root jenkins bash -c "chmod 666 /var/run/docker.sock"
  ```
  (ou mieux : ajouter le bon group gid docker au conteneur)
- Production demande une validation manuelle (`input`) avant déploiement.
- Slack utilise le credential `slack-webhook`.
