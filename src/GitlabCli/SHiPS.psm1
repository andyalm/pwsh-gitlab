using namespace Microsoft.PowerShell.SHiPS

class GitlabInstance : SHiPSDirectory
{
    GitlabInstance() : base($this.GetType())
    {
    }

    GitlabInstance([string]$name): base($name)
    {
    }

    [object[]] GetChildItem()
    {
        return Get-GitlabGroup | % { [GitlabSHiPSGroup]::New($_) }
    }
}

class GitlabSHiPSGroup : SHiPSDirectory
{
    [object]$Group;
    GitlabSHiPSGroup($Group) : base($Group.Name)
    {
        $this.Group = $Group;
    }

    [object[]] GetChildItem()
    {
        return @()
    }
}