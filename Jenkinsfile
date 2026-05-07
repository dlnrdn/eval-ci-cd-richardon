pipeline {
  agent none
  options {
    ansiColor('xterm')
    skipDefaultCheckout()
    timestamps()
  }
  parameters {
    booleanParam(name: 'SECURITY_STRICT_MODE', defaultValue: true, description: 'Si activé, les étapes de sécurité bloquent la pipeline en cas de détection.')
  }
  environment {
    DISCORD_WEBHOOK = credentials('discord-webhook')
    RENDER_DEPLOY_HOOK = credentials('render-deploy-hook')
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
        sh 'apk add --no-cache curl'
        sh 'curl -s -X POST -H "Content-Type: application/json" -d "{}" "$RENDER_DEPLOY_HOOK"'
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
        notifyDiscord('SUCCESS', "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER} a réussi : ${env.BUILD_URL}")
      }
    }
    unstable {
      script {
        notifyDiscord('UNSTABLE', "⚠️ ${env.JOB_NAME} #${env.BUILD_NUMBER} instable : ${env.BUILD_URL}")
      }
    }
    failure {
      script {
        notifyDiscord('FAILURE', "❌ ${env.JOB_NAME} #${env.BUILD_NUMBER} a échoué : ${env.BUILD_URL}")
      }
    }
  }
}

def notifyDiscord(String status, String message) {
  sh "curl -s -X POST -H 'Content-Type: application/json' -d '{\"content\": \"${message}\"}' '${DISCORD_WEBHOOK}'"
}
