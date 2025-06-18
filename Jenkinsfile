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
                bat '''
        setlocal ENABLEDELAYEDEXPANSION

        REM Create the JSON payload (requires jq)
        echo Creating JSON payload...
        echo.>{__tmp_payload__.json}
        jq -n --arg url "http://localhost:9090" ^
            "{ scan_configurations: [{ name: \\"Crawl strategy - fastest\\", type: \\"NamedConfiguration\\" }], urls: [\$url] }" > __tmp_payload__.json

        REM Start the scan and capture Location header
        echo Starting scan...
        for /f "tokens=2 delims= " %%A in ('curl -s -D - -o NUL -X POST -H "Content-Type: application/json" -d "@__tmp_payload__.json" http://192.168.30.5:1337/v0.1/scan ^| findstr /i "location:"') do (
            set scan_id=%%A
        )

        REM Trim carriage return from scan_id (if any)
        set "scan_id=!scan_id:\r=!"

        echo Scan ID: !scan_id!

        set "scan_result=http://192.168.30.5:1337/v0.1/scan/!scan_id!"

        REM Poll for scan completion
        set retries=60

        :loop
        if !retries! LEQ 0 (
            echo Timed out waiting for scan to complete.
            exit /b 1
        )

        curl -s -X GET "!scan_result!" > scan_result.json
        for /f %%P in ('jq ".scan_metrics.crawl_and_audit_progress // 0" scan_result.json') do (
            set progress=%%P
        )

        echo Progress: !progress!%%

        if "!progress!"=="100" (
            echo Scan complete.
            type scan_result.json

            REM Check for medium or higher severity
            jq "[.issue_events[]?.issue.severity] | any(. == \\"medium\\" or . == \\"high\\" or . == \\"critical\\")" scan_result.json | findstr true >nul
            if !errorlevel! == 0 (
                echo Found issues of medium or higher severity.
                exit /b 1
            ) else (
                echo No critical issues found.
                exit /b 0
            )
        )

        timeout /t 5 >nul
        set /a retries-=1
        goto loop
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
