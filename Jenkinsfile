pipeline {
    agent any

    tools {
        nodejs 'node'  // match the name you used in Global Tool Configuration
    }

    environment {
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
                scanner_home = tool 'Sonar'  // match the name you used in Global Tool Configuration
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
                docker run -d --name tiktaktoe -p 9090:80 tiktaktoe:latest
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                bat '''
                mkdir .\\results
                REM Should select the path you want to save the results, for easier access.
                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image -f json tiktaktoe:latest > .\\results\\scan.json  
                '''
            }
        }

        stage('BurpSuite Scan') {
            steps {
                powershell '''
            ssh rubens@192.168.30.5 "cd ~/Documents/tiktaktoeCICD && git fetch && git pull && docker build -t tiktaktoe:latest . && docker rm -f tiktaktoe-container; docker run -d --name tiktaktoe-container -p 9000:80 tiktaktoe:latest"


            # Configuration
            $burpServer = "http://192.168.30.5:1337"
            $targetUrl = "http://localhost:9000"
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
                $response = Invoke-WebRequest -Uri "$burpServer/v0.1/scan" -Method POST -Headers $headers -Body $payload

                $scanId = $response.Headers.Location
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

            ssh rubens@192.168.30.5 "docker rm -f tiktaktoe-container"
        '''
            }
        }

        stage('Update Kubernetes') {
            steps {
                powershell '''
                git checkout main
                git config user.email = "rn.sousa@campus.fct.unl.pt"
                git config user.name = "RSmistia"
                git fetch
                git pull

                $gitsha = git rev-parse HEAD

                (Get-Content .\\kubernetes\\deployment.yaml) -replace 'image: ghcr.io/rsmistia/tiktaktoecicd:sha-[0-9a-f]+', "image: ghcr.io/rsmistia/tiktaktoecicd:sha-$gitsha" | Set-Content .\\kubernetes\\deployment.yaml

                git add kubernetes/deployment.yaml
                git commit -m "Update Kubernetes deployment with new image sha: $sha [skip ci]" 
                if ($LASTEXITCODE -ne 0) {
                    Write-Output "Nochanges to commit"
                    exit 1
                }
                git push
                '''
            }
        }

        stage('Remove Temporary Container') {
            steps{
                bat '''
                    REM Remove this step if you want to keep the container for testing purposes, for the next Jenkins build,
                    REM you must delete the container manually, for the correct behavior to happen.
                    docker rm -f tiktaktoe
                '''
            }
        }
    }
}
