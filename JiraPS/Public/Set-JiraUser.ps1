function Set-JiraUser {
    [CmdletBinding( SupportsShouldProcess, DefaultParameterSetName = 'ByNamedParameters' )]
    param(
        [Parameter( Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.User" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Type for Parameter"),
                        'ParameterType.NotJiraUser',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $_
                    )
                    $errorItem.ErrorDetails = "Wrong object type provided for User. Expected [JiraPS.User] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Alias('UserName')]
        [Object[]]
        $User,

        [Parameter( ParameterSetName = 'ByNamedParameters' )]
        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [Parameter( ParameterSetName = 'ByNamedParameters' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if ($_ -match '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$') {
                    return $true
                }
                else {
                    $errorItem = [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid Argument"),
                        'ParameterValue.NotEmail',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Issue
                    )
                    $errorItem.ErrorDetails = "The value provided does not look like an email address."
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    return $false
                }
            }
        )]
        [String]
        $EmailAddress,

        [Parameter( Position = 1, Mandatory, ParameterSetName = 'ByHashtable' )]
        [Hashtable]
        $Property,

        [PSCredential]
        $Credential,

        [Switch]
        $PassThru
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/user?username={0}"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        foreach ($_user in $User) {
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_user]"
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_user [$_user]"

            $userObj = Get-JiraUser -UserName $_user -Credential $Credential -ErrorAction Stop

            $requestBody = @{}

            switch ($PSCmdlet.ParameterSetName) {
                'ByNamedParameters' {
                    if (-not ($DisplayName -or $EmailAddress)) {
                        $errorMessage = @{
                            Category         = "InvalidArgument"
                            CategoryActivity = "Validating Arguments"
                            Message          = "The parameters provided do not change the User. No action will be performed"
                        }
                        Write-Error @errorMessage
                        return
                    }

                    if ($DisplayName) {
                        $requestBody.displayName = $DisplayName
                    }

                    if ($EmailAddress) {
                        $requestBody.emailAddress = $EmailAddress
                    }
                }
                'ByHashtable' {
                    $requestBody = $Property
                }
            }

            $parameter = @{
                URI        = $resourceURi -f $userObj.Name
                Method     = "PUT"
                Body       = ConvertTo-Json -InputObject $requestBody -Depth 4
                Credential = $Credential
            }
            Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
            if ($PSCmdlet.ShouldProcess($UserObj.DisplayName, "Updating user")) {
                $result = Invoke-JiraMethod @parameter

                if ($PassThru) {
                    Write-Output (Get-JiraUser -inputObject $result)
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
