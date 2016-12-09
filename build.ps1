# Helper method to stop execution on first error
function Exec
{
  [CmdletBinding()]
  param(
    [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
    [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ($msgs.error_bad_command -f $cmd)
  )
  & $cmd
  if ($lastexitcode -ne 0) {
    throw ("Exec: " + $errorMessage)
  }
}


if (Test-Path .\artifacts) {
  echo "build: Cleaning .\artifacts"
  Remove-Item .\artifacts -Force -Recurse
}


exec { & dotnet restore --no-cache }


# Generate suffix based on branch and revision. If branch is master with a valid build number, so suffix is empty (used for official releases)
$branch = @{ $true = $env:APPVEYOR_REPO_BRANCH; $false = $(git symbolic-ref --short -q HEAD) }[$env:APPVEYOR_REPO_BRANCH -ne $NULL]
$revision = @{ $true = "{0}" -f [convert]::ToInt32("0" + $env:APPVEYOR_BUILD_NUMBER, 10); $false = "local" }[$env:APPVEYOR_BUILD_NUMBER -ne $NULL]
$branch = $branch.Replace('/', '-')
$suffix = @{ $true = ""; $false = "$($branch.Substring(0, [math]::Min(10,$branch.Length)))-$revision"}[$branch -eq "master" -and $revision -ne "local"]
echo "Version suffix is '$suffix'"


# Patch project.json and use value from APPVEYOR_BUILD_VERSION
if ($env:APPVEYOR_BUILD_VERSION -ne $NULL)
{
  Get-ChildItem -Path .\ -Recurse -File -Filter project.json | foreach {
    $jsonFile = Get-Content $_.FullName -raw | ConvertFrom-Json
    if ($jsonFile.version) {
        $jsonFile.version = ([version]$ENV:APPVEYOR_BUILD_VERSION).ToString(3) + '-*'
        echo "Updated $_.FullName with version $jsonFile.version"
        $jsonFile | ConvertTo-Json -Depth 100 | Out-File $_.FullName
    }
  }
}

exec { & dotnet test .\SlackAPI.Tests -c Release }
exec { & dotnet pack .\SlackAPI -c Release -o .\artifacts --version-suffix=$suffix }
