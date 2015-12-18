#requires -Version 3 -Modules Hyper-V, NetNat, NetSecurity

Param (
    [Parameter(Mandatory = $true)]
    [string]$containername
)
If (-Not(Test-Path -Path C:\temp)) 
{
    New-Item -ItemType Directory -Path C:\temp
}
Start-Transcript -OutputDirectory C:\temp
# Waiting for the Custom Extension to complete before proceeding...

Start-Sleep -Seconds 120

# Get Container Image

$image = Get-ContainerImage -Name 'WindowsServerCore' -Verbose

# Create new Container and install Web-Server

$container = New-Container -Name 'Temp' -ContainerImageName $image.Name -ContainerComputerName 'Temp' -SwitchName (Get-VMSwitch).Name -RuntimeType Default -Verbose

# Start the newly created Container

Start-Container $container -Verbose

# Install Web-Server within the container
#Try
#{
#    $ReturnMessage = Invoke-Command -ContainerName $container.Name -RunAsAdministrator -ErrorAction Stop -ScriptBlock {
#        try
#        {
#            Install-WindowsFeature -Name Web-Server -IncludeManagementTools
#            Write-Verbose -Message 'IIS Installed'
#            Return 'IIS Installed'
#        }
#		
#        catch
#        {
#            Write-Verbose -Message 'Failed to Install IIS'
#            Return $_
#        }
#    } -Verbose
#}
#Catch
#{
#    Write-Verbose -Message 'Invoke-Command Failed'
#    Write-Verbose -Message $ReturnMessage
#    Write-Error $_
#	
#    Write-Verbose -Message 'Trying again'
#    Invoke-Command -ContainerName $container.Name -RunAsAdministrator -ErrorAction Stop -ScriptBlock {
#        try
#        {
#            Install-WindowsFeature -Name Web-Server -IncludeManagementTools
#            Write-Verbose -Message 'IIS Installed'
#            Return 'IIS Installed'
#        }
#		
#        catch
#        {
#            Write-Verbose -Message 'Failed to Install IIS'
#            Return $_
#        }
#    } -Verbose
#}
#Write-Verbose -Message $ReturnMessage 

Dir x:

While (!($?)) {
Invoke-Command -ContainerName $container.Name -RunAsAdministrator -ErrorAction Stop -ScriptBlock {
        try
        {
            Install-WindowsFeature -Name Web-Server -IncludeManagementTools
            Write-Verbose -Message 'IIS Installed'
            Return 'IIS Installed'
        }
		
        catch
        {
            Write-Verbose -Message 'Failed to Install IIS'
            Return $_
        }
    } -Verbose

}

# Stop the newly created Container

Stop-Container -Container $container -Verbose

# Create new Container image for Web Server

$newImage = New-ContainerImage -Container $container -Name 'Web1' -Version 1.0.0.0 -Publisher knese -Verbose

# Create new Container based on Web Server container image

$newcontainer = New-Container -Name $containername -ContainerImageName $newImage.Name -ContainerComputerName $containername -SwitchName (Get-VMSwitch).Name -RuntimeType Default -Verbose

# Start new Container containing the Web Server

Start-Container $newcontainer -Verbose

# Creating NAT rules and port config for container

if (!(Get-NetNatStaticMapping | Where-Object -FilterScript {
            $_.ExternalPort -eq 80
}))
{
    Add-NetNatStaticMapping -NatName 'ContainerNat' -Protocol TCP -ExternalIPAddress 0.0.0.0 -InternalIPAddress 172.16.0.2 -InternalPort 80 -ExternalPort 80
}

if (!(Get-NetFirewallRule | Where-Object -FilterScript {
            $_.Name -eq 'TCP80'
}))
{
    New-NetFirewallRule -Name 'TCP80' -DisplayName 'HTTP on TCP/80' -Protocol tcp -LocalPort 80 -Action Allow -Enabled True
}

Write-Host -Object 'You are done :-)'
Stop-Transcript