<#
    .SYNOPSIS
        Prepapre Symantec Endpoint Protection for Image Managemement Software
	.Description
      	Create HostID based on MACAddress
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 24.09.2012 MS: Script created
		Last Change: 18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		Last Change: 18.09.2013 MS: replace $PVsWriteCacheDisk to global environment variable $LIC_PVS_HostIDPath
		Last Change: 17.12.2013 MS: change service to smc -start for SEP 12 or higher
		Last Change: 27.01.2014 MS: $HostID_Prfx = "00000000000000000000"
		Last Change: 27.01.2014 MS: Set-Location $SEP_path
		Last Change: 28.01.2014 MS: $service_name = "cmd /c smc -start"
		Last Change: 28.01.2014 MS: $reg_SEP_name
		Last Change: 10.03.2014 MS: Review Code
		Last Change: 11.03.2014 MS: IF (Test-Path ("$SEP_path\smc.exe"))
		Last Change: 18.03.2014 BR: revisited Script
		Last Change: 13.08.2014 MS: remove $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		Last Change: 17.08.2014 MS: change line 32 to $SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
		Last Change: 31.08.2015 MS: bugfix 89 - symantec fixes the registry location for the SEP-Client to WOW6432Node, fix in line 31-32 and function SetHostID
		Last Change: 01.09.2015 MS: Bugfix 89 sucessfull tested
		Last Change: 06.10.2015 MS: rewritten script with standard .SYNOPSIS, central BISF function couldn't used for services, SEP Service must being started with smc.exe
		Last Change: 09.01.2017 MS: change code to get MacAdress to use function Get-BISMACAddress
		Last Change: 01.07.2018 MS: Hotfix 49: After SEP is started with smc.exe, sometimes the service will not be started. Controlled and logged now with Test-BISFServiceState in Line 58
		Last Change:
	.Link
#>

Begin {
	$reg_SEP_string = "Symantec\Symantec Endpoint Protection\SMC\SYLINK\SyLink"
	$Product = "Symantec Enterprise Protection"
	$ServiceName = "SepMasterService"
	$HKLM_reg_SEP_string = "$HKLM_sw_x86\$reg_SEP_string"
	$SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
	$reg2Check = "SerialNumber"
	$reg_SEP_name = "HardwareID"
	$HostID_Prfx = "00000000000000000000"
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
}


Process {

	## Start SEP Service
	function StartSEP
	{
		Write-BISFLog -Msg "Start Service $($ServiceName.DisplayName)"
		& $ProgramFilesx86'\Symantec\Symantec Endpoint Protection\smc.exe' "-start"
		Test-BISFServiceState -ServiceName $ServiceName -Status "Running"
	}


	## set HostID in Registry
	function SetHostID
	{
		# 31.08.2015 MS: check if Sep Registry Key exists in registry location
		$TestSEPinReg = Test-BISFRegistryValue -Path $HKLM_reg_SEP_string -Value $reg2Check
		IF ($TestSEPinReg -eq $false)
		{
			$HKLM_reg_SEP_string = "$hklm_software\$reg_SEP_string"
			$TestSEPinReg = Test-BISFRegistryValue -Path $HKLM_reg_SEP_string -Value $reg2Check
		}

		IF ($TestSEPinReg -eq $true)
		{
			Write-BISFLog -Msg "Registry Location for specified SEP Keys would be set to $HKLM_reg_SEP_string"

			$mac = Get-BISFMACAddress
			Write-BISFLog -Msg "$reg_SEP_name Prefix: $HostID_Prfx"
			$regHostID =$HostID_Prfx+$mac
			Write-BISFLog -Msg "$reg_SEP_name would be defined to: $regHostID"
			Write-BISFLog -Msg "set $reg_SEP_name in Registry $HKLM_reg_SEP_string"
			Set-ItemProperty -Path $HKLM_reg_SEP_string -Name $reg_SEP_name -value $regHostID -ErrorAction SilentlyContinue
		} ELSE {
			Write-BISFLog -Msg "Registry Location for specified SEP Keys could not be set to $HKLM_reg_SEP_string" -Type W -SubMsg
			Write-BISFLog -Msg " The Value $reg2Check does not exits in the abive location !!" -Type W -SubMsg
			Write-BISFLog -Msg "The SEP Service woub be started, but each boot that creates ghostentries in the SEP Management Server" -Type W -SubMsg
		}
	}
	####################################################################

	#### Main Program
	IF (Test-Path ("$SEP_path\smc.exe") -PathType Leaf)
	{
		Write-BISFLog -Msg "Symantec Endpoint Protection installed" -ShowConsole -Color Cyan
		SetHostID
		StartSEP
	} ELSE {
		Write-BISFLog -Msg "Symantec Endpoint Protection NOT installed"
	}

}


End {
	Add-BISFFinishLine
}