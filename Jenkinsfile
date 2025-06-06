pipeline {
    agent any

    tools {
        nodejs 'node'  // match the name you used in Global Tool Configuration
    }

    environment {
        REGISTRY = "ghcr.io"
        IMAGE_NAME = "${env.JOB_NAME}".toLowerCase()
        SSH_KEY_PATH = "${env.WORKSPACE}\\.ssh\\id_rsa_autossh"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install and Test') {
            steps {
                bat 'npm ci'
                bat 'npm test || echo No tests found'
            }
        }

        stage('SonarQube Scan') {
            environment {
                scanner_home = tool 'Sonar'
            }
            steps {
                withSonarQubeEnv('MySonarQube') {
                    bat 'sonar-scanner.bat'
                }
            }
        }

        stage('Build') {
            steps {
                bat 'npm run build'
                archiveArtifacts artifacts: 'dist\\**', fingerprint: true
            }
        }

        stage('Docker Build & Trivy Scan') {
            steps {
                bat """
                docker build -t %REGISTRY%/%IMAGE_NAME%:latest .
                docker images
                trivy image --exit-code 1 --severity CRITICAL,HIGH %REGISTRY%/%IMAGE_NAME%:latest
                """
            }
        }

        stage('Serveo & BurpSuite Scan') {
            steps {
                bat '''
                REM This is a placeholder. You'll need to adapt your Bash script to PowerShell or batch
                echo Simulating Serveo tunnel and BurpSuite scan...
                '''
            }
        }

        stage('Update Kubernetes') {
            when {
                allOf {
                    branch 'main'
                    expression { return currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            environment {
                TOKEN = credentials('github-token')
            }
            steps {
                bat '''
                git config user.name "Jenkins"
                git config user.email "jenkins@example.com"

                FOR /F %%i IN ('git rev-parse --short HEAD') DO SET IMAGE_TAG=sha-%%i
                SET "NEW_IMAGE=%REGISTRY%/%IMAGE_NAME%:%IMAGE_TAG%"
                
                powershell -Command "(Get-Content kubernetes\\deployment.yaml) -replace 'image: ghcr.io/.+', 'image: %NEW_IMAGE%' | Set-Content kubernetes\\deployment.yaml"

                git add kubernetes\\deployment.yaml
                git commit -m "Update image tag to %IMAGE_TAG%" || echo No changes
                git push
                '''
            }
        }
    }
}
