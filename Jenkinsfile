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
                bat 'npm test || echo "No tests found!"'
            }
        }

        stage('SonarQube Scan') {
            environment {
                scanner_home = tool 'Sonar'
            }
            steps {
                withSonarQubeEnv('Sonar') {
                    bat "${scanner_home}/bin/sonar-scanner"
                }
            }
        }

        stage('Build') {
            steps {
                bat 'npm run build'
                archiveArtifacts artifacts: 'dist\\**', fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                bat '''
                docker build -t tiktaktoe:latest .
                docker run -d -p 9090:80 tiktaktoe:latest
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                bat '''
                mkdir .\\results
                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image -f json tiktaktoe:latest > .\\results\\scan.json
                '''
            }
        }

        stage('BurpSuite Scan') {
            steps {
                bat '''
                    REM Build the JSON payload with jq
                    json_payload=$(jq -n --arg url "$public_url" '{
                        scan_configurations: [{
                            name: "Crawl strategy - fastest",
                            type: "NamedConfiguration"
                        }],
                        urls: [$url]
                    }')
                    
                    REM Send the POST request and capture the Location header
                    scan_id=$(curl -s -D - -o /dev/null -X POST \
                        -H "Content-Type: application/json" \
                        -d "$json_payload" \
                        "http://192.168.30.5:1337/v0.1/scan" \
                        | awk '/^location:/ { print $2 }' | tr -d '\r')

                    echo "Scan ID: $scan_id"

                    scan_result="http://192.168.30.5:1337/v0.1/scan/$scan_id"

                    echo "Waiting for scan to complete..."
                    retries=60  
                    while [ $retries -gt 0 ]; do
                    result=$(curl -s -X GET "$scan_result")
                    progress=$(echo "$result" | jq '.scan_metrics.crawl_and_audit_progress // 0')
  
                    echo "Progress: $progress%"
                    if [ "$progress" -eq 100 ]; then
                    echo "Scan complete."
                    echo "$result"
                    
                    REM Check for high severity issues
                    echo "$result" | jq '
                        [.issue_events[]?.issue.severity] | any(. == "medium")
                            ' | grep -q true && exit 1

                    exit 0
                    fi
                    
                    sleep 5
                    ((retries--))
                    done

                    echo "Timed out waiting for scan to complete."
                    exit 1
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
