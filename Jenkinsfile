pipeline {
  agent none
  options {
    skipDefaultCheckout()
    timestamps()
  }
  parameters {
    booleanParam(name: 'SECURITY_STRICT_MODE', defaultValue: true, description: 'Si activé, les étapes de sécurité bloquent la pipeline en cas de détection.')
  }
  environment {
    RENDER_APP_URL = ''
  }
  stages {
    stage('Checkout') {
      agent any
      steps {
        deleteDir()
        checkout scm
      }
    }
    stage('Install') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        sh 'npm ci'
      }
    }
    stage('Lint') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        sh 'npm run lint'
      }
    }
    stage('Tests') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        sh 'npm test'
      }
    }
    stage('Coverage') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        sh 'npm run test:coverage -- --coverageThreshold={"global":{"lines":70,"statements":70,"functions":50,"branches":15}}'
      }
    }
    stage('SCA') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        script {
          def status = sh(returnStatus: true, script: 'npm audit --audit-level=moderate')
          if (status != 0) {
            if (params.SECURITY_STRICT_MODE) {
              error('SCA: vulnérabilités détectées')
            }
            unstable('SCA a détecté des vulnérabilités')
          }
        }
      }
    }
    stage('SAST') {
      agent {
        docker {
          image 'returntocorp/semgrep:latest'
          args '-u root:root'
        }
      }
      steps {
        script {
          def status = sh(returnStatus: true, script: 'semgrep --config auto --json --output semgrep-report.json .')
          if (status != 0) {
            if (params.SECURITY_STRICT_MODE) {
              error('SAST: problèmes détectés par Semgrep')
            }
            unstable('SAST a détecté des problèmes')
          }
        }
      }
    }
    stage('Secrets scan') {
      agent {
        docker {
          image 'ghcr.io/gitleaks/gitleaks:latest'
          args '-u root:root'
        }
      }
      steps {
        script {
          def status = sh(returnStatus: true, script: 'gitleaks detect --source . --report-path gitleaks-report.json')
          if (status != 0) {
            if (params.SECURITY_STRICT_MODE) {
              error('Secrets scan: secrets détectés')
            }
            unstable('Secrets scan a détecté des secrets potentiels')
          }
        }
      }
    }
    stage('Validation manuelle') {
      agent any
      steps {
        input message: 'Déployer sur Render ?', ok: 'Oui'
      }
    }
    stage('Deploy') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        script {
          withCredentials([string(credentialsId: 'render-deploy-hook', variable: 'RENDER_DEPLOY_HOOK')]) {
            sh 'apk add --no-cache curl'
            sh 'curl -s -X POST -H "Content-Type: application/json" -d "{}" "$RENDER_DEPLOY_HOOK"'
          }
        }
      }
    }
    stage('Healthcheck') {
      agent {
        docker {
          image 'node:20-alpine'
          args '-u root:root'
        }
      }
      steps {
        sh 'apk add --no-cache curl'
        sh 'if [ -z "$RENDER_APP_URL" ]; then echo "RENDER_APP_URL n\'est pas défini"; exit 1; fi'
        sh 'curl -f "$RENDER_APP_URL/health"'
      }
    }
  }
  post {
    success {
      script {
        node {
          notifyDiscord('SUCCESS', "✅ Dylan Richardon - Job: ${env.JOB_NAME} | Build: #${env.BUILD_NUMBER} | Statut: SUCCESS | URL: ${env.BUILD_URL}")
        }
      }
    }
    unstable {
      script {
        node {
          notifyDiscord('UNSTABLE', "⚠️ Dylan Richardon - Job: ${env.JOB_NAME} | Build: #${env.BUILD_NUMBER} | Statut: UNSTABLE | URL: ${env.BUILD_URL}")
        }
      }
    }
    failure {
      script {
        node {
          notifyDiscord('FAILURE', "❌ Dylan Richardon - Job: ${env.JOB_NAME} | Build: #${env.BUILD_NUMBER} | Statut: FAILURE | URL: ${env.BUILD_URL}")
        }
      }
    }
  }
}

def notifyDiscord(String status, String message) {
  withCredentials([string(credentialsId: 'discord-webhook', variable: 'DISCORD_WEBHOOK')]) {
    sh "curl -s -X POST -H 'Content-Type: application/json' -d '{\"content\": \"${message}\"}' \"${DISCORD_WEBHOOK}\""
  }
}
