pipeline {
  // Agent léger : images Docker Hub déjà prêtes (évite de builder agent/Dockerfile sur t3.micro)
  agent none

  environment {
    IMAGE_NAME = 'alvirra/paymybuddy'
    IMAGE_TAG = "${env.BUILD_NUMBER}"
    FULL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
    STAGING_HOST = '56.228.41.32'
    PROD_HOST = '13.60.222.9'
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {

    stage('Tests Automatisés') {
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          args '-v /root/.m2:/root/.m2 -u root'
        }
      }
      steps {
        sh 'mvn -B clean test'
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Qualité SonarCloud') {
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          args '-v /root/.m2:/root/.m2 -u root'
        }
      }
      steps {
        withSonarQubeEnv('SonarCloud') {
          sh 'mvn -B verify sonar:sonar -s .m2/settings.xml -DskipTests'
        }
      }
    }

    stage('Quality Gate') {
      agent any
      steps {
        timeout(time: 3, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: false
        }
      }
    }

    stage('Compilation et Packaging') {
      agent {
        docker {
          image 'maven:3.9-eclipse-temurin-17'
          args '-v /root/.m2:/root/.m2 -u root'
        }
      }
      steps {
        sh 'mvn -B clean package -DskipTests'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
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
