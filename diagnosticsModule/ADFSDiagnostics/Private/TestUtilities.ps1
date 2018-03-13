Function Create-NotRunOnSecondaryTestResult
{
    param(
        [string] $testName
    )
    $testResult = New-Object TestResult -ArgumentList($testName)
    $testResult.Result = [ResultType]::NotRun;
    $testResult.Detail = "This check runs only on Primary Nodes."
    return $testResult
}

Function Create-NotRunExceptionTestResult
{
    param(
        [string]
        $testName,
        [string]
        $exceptionMessage
    )
    $testResult= New-Object TestResult -ArgumentList($testName);
    $testResult.Result = [ResultType]::NotRun;
    $testResult.Detail = $exceptionMessage;
    $testResult.ExceptionMessage = $exceptionMessage
    return $testResult;
}

Function Invoke-TestFunctions($role, [array]$functionsToRun)
{
    $results = @()
    $totalFunctions = $functionsToRun.Count
    $functionCount = 0
    foreach($function in $functionsToRun)
    {
        $functionCount++
        $percent = 100 * $functionCount / $totalFunctions
        Write-Progress -Activity "Executing Tests for $role" -Status $function -PercentComplete $percent
        $result = Invoke-Expression $function
        $results = $results + $result
    }
    return $results
}

Function TestAdfsSTSHealth()
{
    Param
    (
        $verifyO365 = $true
    )

    $role = Get-ADFSRole

    if ($role -ne "STS")
    {
        return
    }

    # Get OS Version to determine ADFS Version
    $OSVersion = [System.Environment]::OSVersion.Version
    $ADFSVersion = Get-AdfsVersion -OSVersion $OSVersion

    Import-ADFSAdminModule

    #force refresh of ADFS Properties

    try
    {
        $props = Retrieve-AdfsProperties -force
    }
    catch
    {
        #do nothing, other than prevent the error record to go to the pipeline
    }


    $functionsToRun = @( `
        "TestIsAdfsRunning", `
        "TestIsWidRunning", `
        "TestPingFederationMetadata", `
        "TestSslBindings", `
        "Test-AdfsCertificates", `
        "TestADFSDNSHostAlias", `
        "TestADFSDuplicateSPN", `
        "TestServiceAccountProperties", `
        "TestAppPoolIDMatchesServiceID", `
        "TestComputerNameEqFarmName", `
        "TestSSLUsingADFSPort", `
        "TestSSLCertSubjectContainsADFSFarmName", `
        "TestAdfsAuditPolicyEnabled", `
        "TestAdfsRequestToken");

    if ($verifyO365 -eq $true)
    {
        $functionsToRun = $functionsToRun + @( `
        "TestOffice365Endpoints"
        "TestADFSO365RelyingParty"
        "TestNtlmOnlySupportedClientAtProxyEnabled" )
    }

    Invoke-TestFunctions -role "STS" -functionsToRun $functionsToRun
}

Function TestAdfsProxyHealth()
{
    $functionsToRun = @("TestIsAdfsRunning", "TestSTSReachableFromProxy")
    Invoke-TestFunctions -role "Proxy" -functionsToRun $functionsToRun
}