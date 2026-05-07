$ErrorActionPreference = "Stop"
$ImageName = "quicknotes-jenkins"
$ContainerName = "jenkins-quicknotes"
$JenkinsHome = "$PWD\jenkins_home"
if (-not (Test-Path $JenkinsHome)) {
    New-Item -ItemType Directory -Path $JenkinsHome | Out-Null
}
docker build -t $ImageName -f .\jenkins\Dockerfile.jenkins .
$Existing = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}"
if ($Existing -eq $ContainerName) {
    docker rm -f $ContainerName | Out-Null
}
docker run -d `
  --name $ContainerName `
  -p 8080:8080 `
  -p 50000:50000 `
  -v "$JenkinsHome:/var/jenkins_home" `
  -v "/var/run/docker.sock:/var/run/docker.sock" `
  -u root `
  $ImageName
Write-Host "Jenkins lancé : http://localhost:8080"
Write-Host "Mot de passe initial :"
docker exec -it $ContainerName cat /var/jenkins_home/secrets/initialAdminPassword
