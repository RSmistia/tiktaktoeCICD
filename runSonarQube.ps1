#author Ruben Sousa, Timestamp SGS

$container_name="sonarqube-instance"
$sonar_external_port=8000
$sonar_internal_port=9000
$sonar_host="http://localhost:$sonar_external_port"
$sonar_projects="benchmark"
$sonar_user="admin"
$sonar_default_password="admin"
$sonar_password="P4ssword!!!!"

docker pull sonarqube

echo "Creating SonarQube instance..."

docker run --rm -d --name $container_name -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true -p $sonar_external_port":"$sonar_internal_port sonarqube

echo ""

echo "Waiting for SonarQube to start..."

while ($true) {
	try {
		$response = Invoke-WebRequest -Uri $sonar_host -UseBasicParsing -TimeoutSec 5
		if ($response.StatusCode -eq 200) { break }
	} catch {
		# Ignore and retry
	}
	Write-Host "." -NoNewLine
	Start-Sleep -Seconds 3
}

echo ""
echo "Waiting for SonarQube to become ready..."

do{
	$status = try{
		$response = Invoke-WebRequest -Uri "$sonar_host/api/system/status" -UseBasicParsing
        	($response.Content | ConvertFrom-Json).status
		} catch {
			""
		}
	Write-Host "." -NoNewLine
	sleep 3
} while ($status -ne "UP")

echo ""

echo "SonarQube ready. Setting up instance..."
