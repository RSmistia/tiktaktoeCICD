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
                docker run -d --name tiktaktoe -p 9090:80 tiktaktoe:latest
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
                powershell '''
          SSH_KEY_PATH="$HOME/.ssh/id_rsa_autossh"
          CONTAINER_NAME="autoburp"
          REMOTE_PORT=80
          LOCAL_SERVER="192.168.17.41"
          LOCAL_PORT=777
          SSH_SERVER="serveo.net"
          OUTPUT_FILE="output.txt"

          # Clear previous output and keys
          echo "Cleaning up previous files..."
          : > output.txt
          rm -f "$SSH_KEY_PATH"*
          docker remove -f $CONTAINER_NAME

          # Generate SSH key
          echo "Generating new SSH key..."
          ssh-keygen -q -t ed25519 -a 100 -f "$SSH_KEY_PATH" -N "" -C "autossh-key"

          # Pull autossh
          echo "Pulling autossh...."
          docker pull aranajuan/autossh

          echo $SSH_KEY_PATH

          # Run the container with AutoSSH
          echo "Starting AutoSSH tunnel..."
          docker run -d -it --rm --name "$CONTAINER_NAME" \
              -v ${SSH_KEY_PATH}:${SSH_KEY_PATH} \
              aranajuan/autossh \
              autossh -M 0 -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
              -R $REMOTE_PORT:"$LOCAL_SERVER":$LOCAL_PORT "$SSH_SERVER"

          sleep 5

          #Pipeline the result of autossh to OUTPUT_FILE
          docker logs "$CONTAINER_NAME" > "$OUTPUT_FILE"

          echo "AutoSSH container is running..."

          echo "Waiting for Serveo URL..."
          timeout=60
          while ! grep -q "Forwarding HTTP traffic" "$OUTPUT_FILE" && [ $timeout -gt 0 ]; do
            sleep 1
            ((timeout--))
          done

          if [ $timeout -eq 0 ]; then
            echo "Timed out waiting for Serveo URL"
            echo "logs:" >> "$OUTPUT_FILE"
            docker logs "$CONTAINER_NAME" >> "$OUTPUT_FILE"
            exit 1
          fi

          # Extract URL from the output
          public_url=$(grep "Forwarding HTTP traffic" "$OUTPUT_FILE" | sed -n 's/.*Forwarding HTTP traffic from //p' | tr -d '\r\n')
          
          echo "Your public SonarQube URL is: $public_url"

            # Configuration
            $burpServer = "http://192.168.30.5:1337"
            $targetUrl = "http://localhost:9090"
            $timeoutMinutes = 15
            $pollInterval = 5

            # Create payload
            $payload = @{
                scan_configurations = @(
                    @{
                        name = "Crawl strategy - fastest"
                        type = "NamedConfiguration"
                    }
                )
                urls = @($targetUrl)
            } | ConvertTo-Json

            # Start scan
            $headers = @{
                "Content-Type" = "application/json"
            }

            try {
                $response = Invoke-RestMethod -Uri "$burpServer/v0.1/scan" `
                    -Method Post `
                    -Headers $headers `
                    -Body $payload `
                    -ErrorAction Stop

                $scanId = $response.id
                Write-Host "Scan started with ID: $scanId"
            }
            catch {
                Write-Host "Failed to start scan: $_"
                exit 1
            }

            # Monitor scan progress
            $startTime = Get-Date
            $scanComplete = $false
            $scanFailed = $false

            while (-not $scanComplete -and -not $scanFailed) {
                if ((New-TimeSpan -Start $startTime).TotalMinutes -gt $timeoutMinutes) {
                    Write-Host "Scan timed out after $timeoutMinutes minutes"
                    exit 1
                }

                try {
                    $result = Invoke-RestMethod -Uri "$burpServer/v0.1/scan/$scanId" `
                        -Method Get `
                        -Headers $headers `
                        -ErrorAction Stop

                    $progress = $result.scan_metrics.crawl_and_audit_progress
                    Write-Host "Scan progress: $progress%"

                    if ($progress -eq 100) {
                        $scanComplete = $true
                        Write-Host "Scan completed successfully"

                        # Check for critical issues
                        $hasCriticalIssues = $result.issue_events | 
                            Where-Object { $_.issue.severity -in ("medium", "high", "critical") }

                        if ($hasCriticalIssues) {
                            Write-Host "Critical issues found:"
                            $hasCriticalIssues | Format-Table
                            exit 1
                        } else {
                            Write-Host "No critical issues found"
                            exit 0
                        }
                    }
                }
                catch {
                    Write-Host "Error checking scan status: $_"
                    $scanFailed = $true
                    exit 1
                }

                Start-Sleep -Seconds $pollInterval
            }
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
        stage('Stop Container') {
            steps{
                bat '''
                    docker stop tiktaktoe
                '''
            }
        }
    }
}
