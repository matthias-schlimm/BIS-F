<#
    .SYNOPSIS
        Prepare McAfee Agent for Image Managemement
	.Description
      	Delete Computer specIfied entries
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
    Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

    History
		Last Change: 10.12.2014 JP: Script created
		Last Change: 15.12.2014 JP: Added automatic virus definitions updates
		Last Change: 06.02.2015 MS: Reviewed script
		Last Change: 19.02.2015 MS: Fixed some errors and add progress bar for running scan
		Last Change: 01.10.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		Last Change: 05.01.2017 JP: Added maconfig.exe See https://community.mcafee.com/external-link.jspa?url=https%3A%2F%2Fkc.mcafee.com%2Fresources%2Fsites%2FMCAFEE%2Fcontent%2Flive%2FPRODUCT_DOCUMENTATION%2F25000%2FPD25187%2Fen_US%2Fma_500_pg_en-us.pdf
		& https://kc.mcafee.com/corporate/index?page=content&id=KB84087
		Last Change: 10.01.2017 MS: Added Script to BIS-F for McAfee 5.0 Support, thx to Jonathan Pitre
		Last Change: 11.01.0217 MS: $reg_agent_version = move (Get-ItemProperty "$reg_agent_string").AgentVersion after Product Installation check, otherwise error in POSH Output RegKey does not exist
		Last Change: 13.01.2017 FF: Search for maconfig.exe under x86 and x64 Program Files
		Last Change: 01.18.2017 JP: Added the detected agent version in the log message
		Last Change: 06.03.2017 MS: Bugfix read Variable $varCLI = ...
		Last Change: 08.01.2017 JP: Fixed typos
        Last Change: 15.10.2018 MS: Bugfix 58 - remove hardcoded maconfig.exe path
	.Link
#>

Begin {
	$Script_Path = $MyInvocation.MyCommand.Path
	$Script_Dir = Split-Path -Parent $Script_Path
	$Script_Name = [System.IO.Path]::GetFileName($Script_Path)

	# Product specIfied
	$Product = "McAfee VirusScan Enterprise"
	$Product2 = "McAfee Agent"
	$reg_product_string = "$hklm_sw_x86\Network Associates\ePolicy Orchestrator\Agent"
    $reg_agent_string = "$hklm_sw_x86\McAfee\Agent"
	$Product_Path = "$ProgramFilesx86\McAfee\VirusScan Enterprise"
	$ServiceName1 = "McAfeeFramework"
	$ServiceName2 = "McShield"
	$ServiceName3 = "McTaskManager"
	$PrepApp = "maconfig.exe"
  	$PrepAppSearchFolder = @("${env:ProgramFiles}\McAfee\Common Framework","${env:ProgramFiles(x86)}\McAfee\Common Framework")
	[array]$reg_product_name = "AgentGUID"
	[array]$reg_product_name += "MacAddress"
	[array]$reg_product_name += "ComputerName"
	[array]$reg_product_name += "IPAddress"
	[array]$reg_product_name += "LastASCTime"
	[array]$reg_product_name += "SequenceNumber"
	[array]$reg_product_name += "SubnetMask"

}

Process {
####################################################################
####### Functions #####
####################################################################

	Function DefUpdates
	{
	    Invoke-BISFService -ServiceName "$ServiceName1" -Action Start
		Write-BISFLog -Msg "Updating virus definitions...please wait"
		Start-Process -FilePath "$Product_Path\mcupdate.exe" -ArgumentList "/update /quiet"
		Show-BISFProgressBar -CheckProcess "mcupdate" -ActivityText "$Product is updating the virus definitions...please wait"
        Start-Sleep -s 3
	}

	Function RunFullScan
	{

	Write-BISFLog -Msg "Check Silentswitch..."
		$varCLI = $LIC_BISF_CLI_AV
		If (($varCLI -eq "YES") -or ($varCLI -eq "NO"))
		{
			Write-BISFLog -Msg "Silentswitch will be set to $varCLI"
		} Else {
           	Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
			$MPFullScan = Show-BISFMessageBox -Msg "Would you like to to run a Full Scan ? " -Title "$Product" -YesNo -Question
        	Write-BISFLog -Msg "$MPFullScan will be choosen [YES = Run Full Scan] [NO = No scan will be performed]"
		}
        If (($MPFullScan -eq "YES" ) -or ($varCLI -eq "YES"))
		{
			Write-BISFLog -Msg "Running Full Scan...please wait"
			Start-Process -FilePath "$Product_Path\Scan32.exe" -ArgumentList "c:\"
			If ($OSBitness -eq "32-bit") {$ScanProcess="Scan32"} Else {$ScanProcess="Scan64"}
			Show-BISFProgressBar -CheckProcess "$ScanProcess" -ActivityText "$Product is scanning the system...please wait"
		} Else {
			Write-BISFLog -Msg "No Full Scan will be performed"
		}

	}

  Function DeleteVSEData
  {
    If ($reg_agent_version -lt "5.0")
    {
		Invoke-BISFService -ServiceName "$ServiceName1" -Action Stop
		Invoke-BISFService -ServiceName "$ServiceName2" -Action Stop
		Invoke-BISFService -ServiceName "$ServiceName3" -Action Stop
		ForEach ($key in $reg_product_name)
		{
		Write-BISFLog -Msg "Delete specIfied registry items in $reg_product_string..."
		Write-BISFLog -Msg "Delete $key"
		Remove-ItemProperty -Path $reg_product_string -Name $key -ErrorAction SilentlyContinue
		}
    }
		If ($reg_agent_version -ge "5.0") {

			$found = $false
			Write-BISFLog -Msg "Searching for $PrepApp on the system" -ShowConsole -Color DarkCyan -SubMsg
			$PrepAppExists = Get-ChildItem -Path "$PrepAppSearchFolder" -filter "$PrepApp" -ErrorAction SilentlyContinue | % {$_.FullName}

			IF (($PrepAppExists -ne $null) -and ($found -ne $true)) {

				If (Test-Path ("$PrepAppExists") -PathType Leaf ) {
					Write-BISFLog -Msg "$PrepApp found in $PrepAppExists" -ShowConsole -Color DarkCyan -SubMsg
					Write-BISFLog -Msg "Removed $Product GUID"
					$found = $true
					& Start-Process -FilePath "$PrepAppExists" -ArgumentList "-enforce -noguid" -Wait
				}
			}
		}
  }


	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
    If (Test-Path ("$Product_Path\shstat.exe") -PathType Leaf)

	{
        Write-BISFLog -Msg "Product $Product installed" -ShowConsole -Color Cyan
        $reg_agent_version = (Get-ItemProperty "$reg_agent_string").AgentVersion
		Write-BISFLog -Msg "Product $Product2 $reg_agent_version installed" -ShowConsole -Color Cyan
        DefUpdates
		RunFullScan
		DeleteVSEData
	} Else {
		Write-BISFLog -Msg "Product $Product NOT installed"
	}
}


End {
	Add-BISFFinishLine
}
