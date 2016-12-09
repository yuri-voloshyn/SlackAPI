
if (Test-Path .\artifacts) {
  echo "build: Cleaning .\artifacts"
  Remove-Item .\artifacts -Force -Recurse
}


& dotnet restore --no-cache


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
        $newVersion = ([version]$ENV:APPVEYOR_BUILD_VERSION).ToString(3) + '-*'
        $jsonFile.version = $newVersion
        echo "Updated $($_.FullName) with version $newVersion"
        $jsonFile | ConvertTo-Json -Depth 100 | Out-File $_.FullName
    }
  }
}

& dotnet test .\SlackAPI.Tests -c Release
if ($lastexitcode -ne 0) { exit 1 }

& dotnet pack .\SlackAPI -c Release -o .\artifacts --version-suffix=$suffix
if ($lastexitcode -ne 0) { exit 1 }
