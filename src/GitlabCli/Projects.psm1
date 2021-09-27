function Get-GitlabProject {

    [CmdletBinding(DefaultParameterSetName='ById')]
    param (
        [Parameter(Position=0, Mandatory=$false, ParameterSetName='ById')]
        [string]
        $ProjectId = '.',

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='ByGroup')]
        [string]
        $GroupId,

        [switch]
        [Parameter(Mandatory=$false, ParameterSetName='ByGroup')]
        $IncludeArchived = $false,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    switch ($PSCmdlet.ParameterSetName) {
        ById {
            if ($ProjectId -eq '.') {
                $ProjectId = $(Get-LocalGitContext).Repo
            }
            $Project = Invoke-GitlabApi GET "projects/$([System.Net.WebUtility]::UrlEncode($ProjectId))"
            if ($Project) {
                return $Project | New-WrapperObject 'Gitlab.Project'
            }
        }
        ByGroup {
            $Group = Get-GitlabGroup $GroupId
            $Query = @{
                'include_subgroups' = 'true'
            }
            if (-not $IncludeArchived) {
                $Query['archived'] = 'false'
            }
            Invoke-GitlabApi GET "groups/$($Group.Id)/projects" $Query -MaxPage 10 |
                Where-Object { $($_.path_with_namespace).StartsWith($Group.FullPath) } |
                New-WrapperObject 'Gitlab.Project' |
                Sort-Object -Property 'Name'
        }
    }
}

function Move-GitlabProject {
    [Alias("Transfer-GitlabProject")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $ProjectId = '.',

        [Parameter(Mandatory=$true)]
        [string]
        $DestinationGroup,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    $SourceProject = Get-GitlabProject -ProjectId $ProjectId
    $Group = Get-GitlabGroup -GroupId $DestinationGroup

    Invoke-GitlabApi PUT "projects/$($SourceProject.Id)/transfer" @{
        namespace = $Group.Id
    } -WhatIf:$WhatIf -WhatIfContext @{
        SourceProjectName = $SourceProject.Name
        NamespacePath = $Group.FullPath
    } | New-WrapperObject 'Gitlab.Project'
}

function Rename-GitlabProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $ProjectId = '.',

        [Parameter(Mandatory=$true)]
        [string]
        $NewName,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    Update-GitlabProject -ProjectId $ProjectId -Name $NewName -Path $NewName -WhatIf:$WhatIf
}

function Copy-GitlabProject {
    [Alias("Fork-GitlabProject")]
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]
        $ProjectId,

        [Parameter(Position=1, Mandatory=$true)]
        [string]
        $DestinationGroup,

        [bool]
        [Parameter(Mandatory=$false)]
        $PreserveForkRelationship = $true,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    $SourceProject = Get-GitlabProject -ProjectId $ProjectId
    $Group = Get-GitlabGroup -GroupId $DestinationGroup

    if ($WhatIf) {
        Write-Host "WhatIf: forking '$($SourceProject.Name)' (project id: $($SourceProject.Id)) to '$($Group.FullPath)' (group id: $($Group.Id))"
    } else {
        $NewProject = Invoke-GitlabApi POST "projects/$($SourceProject.Id)/fork" @{
            namespace_id = $Group.Id
        }
    }

    if (-not $PreserveForkRelationship) {
        if ($WhatIf) {
            Write-Host "WhatIf: removing fork relationship to $($SourceProject.Id)"
        } else {
            Invoke-GitlabApi DELETE "projects/$($NewProject.id)/fork"
        }
    }
}
function New-GitlabProject {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]
        $ProjectName,

        [Parameter(Position=1, Mandatory=$true)]
        [string]
        $DestinationGroup,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    $Group = Get-GitlabGroup -GroupId $DestinationGroup
    if(-not $Group) {
        throw "DestinationGroup '$DestinationGroup' not found"
    }

    Invoke-GitlabApi POST "projects" @{
        name = $ProjectName
        namespace_id = $Group.Id
    } -WhatIf:$WhatIf -WhatIfContext @{
        DestinationGroupName = $Group.Name
    }
}

function Update-GitlabProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $ProjectId = '.',

        [Parameter(Mandatory=$false)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [string]
        $Path,

        [Parameter(Mandatory=$false)]
        [string []]
        $Topics,

        [Parameter(Mandatory=$false)]
        [bool]
        $CiForwardDeployment,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    $Project = Get-GitlabProject $ProjectId

    $Query = @{}

    if($PSBoundParameters.ContainsKey("CiForwardDeployment")){
        $Query['ci_forward_deployment_enabled'] = $CiForwardDeployment
    }
    if ($Name) {
        $Query['name'] = $Name
    }
    if ($Path) {
        $Query['path'] = $Path
    }
    if ($Topics) {
        $Query['topics'] = $Topics -join ','
    }

    Invoke-GitlabApi PUT "projects/$($Project.Id)" $Query -WhatIf:$WhatIf |
        New-WrapperObject 'Gitlab.Project'
}

function Invoke-GitlabProjectArchival {
    [Alias('Archive-GitlabProject')]
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]
        $ProjectId,

        [switch]
        [Parameter(Mandatory=$false)]
        $WhatIf = $false
    )

    $Project = $(Get-GitlabProject -ProjectId $ProjectId)
    
    Invoke-GitlabApi POST "projects/$($Project.Id)/archive" -WhatIf:$WhatIf -WhatIfContext @{
        ProjectName = $Project.Name
    } | New-WrapperObject 'Gitlab.Project'
}
