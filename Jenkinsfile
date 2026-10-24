pipeline {
  agent none

  environment {
    IMAGE_NAME = 'alvirra/paymybuddy'
    IMAGE_TAG = "${env.BUILD_NUMBER}"
    FULL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
    STAGING_HOST = '56.228.41.32'
    PROD_HOST = '13.60.222.9'
    // Heap adapté t3.small (2 Go) — Sonar a besoin de plus que Maven seul
    MAVEN_OPTS = '-Xmx768m -XX:MaxMetaspaceSize=256m'
    SONAR_SCANNER_OPTS = '-Xmx1024m'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '5'))
    timeout(time: 45, unit: 'MINUTES')
  }

  stages {

    // Un seul conteneur Maven = 1 pull, moins de RAM
    stage('Tests + Qualité + Packaging') {
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          args '-v /root/.m2:/root/.m2 -u root --memory=1536m'
        }
      }
      stages {
        stage('Tests Automatisés') {
          steps {
            // Tests unitaires seulement (*Test), exclure les IT trop lourds
            sh 'mvn -B -Dtest="*Test" -DfailIfNoTests=false clean test'
          }
          post {
            always {
              junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
            }
          }
        }
        stage('Qualité SonarCloud') {
          steps {
            withSonarQubeEnv('SonarCloud') {
              sh 'mvn -B verify sonar:sonar -s .m2/settings.xml -DskipTests'
            }
          }
        }
        stage('Quality Gate') {
          steps {
            timeout(time: 2, unit: 'MINUTES') {
              waitForQualityGate abortPipeline: false
            }
          }
        }
        stage('Compilation et Packaging') {
          steps {
            sh 'mvn -B package -DskipTests'
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
          }
        }
      }
    }

    stage('Build & Push DockerHub') {
      agent {
        docker {
          image 'docker:27-cli'
          args '-v /var/run/docker.sock:/var/run/docker.sock -u root'
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKERHUB_USR', passwordVariable: 'DOCKERHUB_PSW')]) {
          sh '''
            set -e
            echo "$DOCKERHUB_PSW" | docker login -u "$DOCKERHUB_USR" --password-stdin
            docker build -t ${FULL_IMAGE} -t ${IMAGE_NAME}:latest .
            docker push ${FULL_IMAGE}
            docker push ${IMAGE_NAME}:latest
          '''
        }
      }
    }

    stage('Staging') {
      when {
        expression { return env.GIT_BRANCH == 'origin/main' || env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' }
      }
      agent {
        docker {
          image 'alpine:3.20'
          args '-u root'
        }
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKERHUB_USR', passwordVariable: 'DOCKERHUB_PSW'),
          sshUserPrivateKey(credentialsId: 'ssh-deploy', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
        ]) {
          sh '''
            set -e
            apk add --no-cache openssh-client
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            cp "$SSH_KEY" ~/.ssh/id_rsa && chmod 400 ~/.ssh/id_rsa
            ssh-keyscan -H "$STAGING_HOST" >> ~/.ssh/known_hosts 2>/dev/null

            ssh -o StrictHostKeyChecking=yes ${SSH_USER}@${STAGING_HOST} "mkdir -p ~/paymybuddy-deploy"
            scp deploy/docker-compose.yml ${SSH_USER}@${STAGING_HOST}:~/paymybuddy-deploy/docker-compose.yml

            ssh -o StrictHostKeyChecking=yes ${SSH_USER}@${STAGING_HOST} "
              set -e
              cd ~/paymybuddy-deploy
              echo '${DOCKERHUB_PSW}' | docker login -u '${DOCKERHUB_USR}' --password-stdin
              export IMAGE_NAME='${FULL_IMAGE}'
              export MYSQL_ROOT_PASSWORD=password
              export MYSQL_USER=root
              docker compose pull
              docker compose up -d
              docker compose ps
            "
          '''
        }
      }
    }

    stage('Validation Staging') {
      when {
        expression { return env.GIT_BRANCH == 'origin/main' || env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' }
      }
      agent {
        docker {
          image 'alpine:3.20'
          args '-u root'
        }
      }
      steps {
        sh '''
          set -e
          apk add --no-cache curl
          chmod +x scripts/validate.sh
          APP_URL="http://${STAGING_HOST}:8080/" RETRIES=30 SLEEP_SECONDS=10 ./scripts/validate.sh
        '''
      }
    }

    stage('Production') {
      when {
        expression { return env.GIT_BRANCH == 'origin/main' || env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' }
      }
      agent {
        docker {
          image 'alpine:3.20'
          args '-u root'
        }
      }
      steps {
        input message: "Déployer en PRODUCTION sur ${PROD_HOST} ?", ok: 'Déployer'
        withCredentials([
          usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKERHUB_USR', passwordVariable: 'DOCKERHUB_PSW'),
          sshUserPrivateKey(credentialsId: 'ssh-deploy', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
        ]) {
          sh '''
            set -e
            apk add --no-cache openssh-client
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            cp "$SSH_KEY" ~/.ssh/id_rsa && chmod 400 ~/.ssh/id_rsa
            ssh-keyscan -H "$PROD_HOST" >> ~/.ssh/known_hosts 2>/dev/null

            ssh -o StrictHostKeyChecking=yes ${SSH_USER}@${PROD_HOST} "mkdir -p ~/paymybuddy-deploy"
            scp deploy/docker-compose.yml ${SSH_USER}@${PROD_HOST}:~/paymybuddy-deploy/docker-compose.yml

            ssh -o StrictHostKeyChecking=yes ${SSH_USER}@${PROD_HOST} "
              set -e
              cd ~/paymybuddy-deploy
              echo '${DOCKERHUB_PSW}' | docker login -u '${DOCKERHUB_USR}' --password-stdin
              export IMAGE_NAME='${FULL_IMAGE}'
              export MYSQL_ROOT_PASSWORD=password
              export MYSQL_USER=root
              docker compose pull
              docker compose up -d
              docker compose ps
            "
          '''
        }
      }
    }

    stage('Validation Production') {
      when {
        expression { return env.GIT_BRANCH == 'origin/main' || env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' }
      }
      agent {
        docker {
          image 'alpine:3.20'
          args '-u root'
        }
      }
      steps {
        sh '''
          set -e
          apk add --no-cache curl
          chmod +x scripts/validate.sh
          APP_URL="http://${PROD_HOST}:8080/" RETRIES=30 SLEEP_SECONDS=10 ./scripts/validate.sh
        '''
      }
    }
  }

  post {
    always {
      node('built-in') {
        script {
          def status = currentBuild.currentResult
          def branch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'N/A'
          try {
            withCredentials([string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')]) {
              sh """
                curl -sS -X POST -H 'Content-type: application/json' \
                  --data '{"text":"*PayMyBuddy CI/CD*\\nStatus: *${status}*\\nJob: ${env.JOB_NAME} #${env.BUILD_NUMBER}\\nBranche: ${branch}\\nURL: ${env.BUILD_URL}"}' \
                  "\$SLACK_WEBHOOK" || true
              """
            }
          } catch (err) {
            echo "Notification Slack ignorée: ${err}"
          }
        }
      }
    }
  }
}
