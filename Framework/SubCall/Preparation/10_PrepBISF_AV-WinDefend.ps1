<#
    .SYNOPSIS
        Prepare Microsoft Windows Defender for Image Management
	.Description
      	Reconfigure Microsoft Windows Defender
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm, Florian Frank
      	Company: Login Consultants Germany GmbH
		
		History
      	Last Change: 25.03.2014 MS: Script created
		Last Change: 01.04.2014 MS: Changed console message
		Last Change: 12.05.2014 MS: Changed Fullscan from Windows Defender directory to '$ProductPath\...'
		Last Change: 13.05.2014 MS: Added Silentswitch -AVFullScan (YES|NO) 
		Last Change: 11.06.2014 MS: Syntax error to start silent pattern update and full scan, fix read variable LIC_BISF_CLI_AV
		Last Change: 13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		Last Change: 20.02.2015 MS: Added progress bar during full scan
		Last Change: 30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		Last Change: 06.03.2017 MS: Bugfix read Variable $varCLI = ...
		Last Change: 31.05.2017 FF: Added changes necessary to prepare Windows Defender and create a seperate script
		Last Change: 08.01.2017 JP: Replaced "C:\Program Files" with windows variable, fixed typos
		Last Change: 02.08.2017 MS: to much " at the end of Line 44, breaks script to fail 
		Last Change: 17.08.2017 FF: Program is named "Windows Defender", not "Microsoft Windows Defender", fixed typos
		Last Change: 08.09.2017 FF: Feature 182 - Windows Defender Signature will only be updated if Defender is enabled to run
		Last Change: 20.10.2018 MS: Bugfix 55: Windows Defender -ArgumentList failing
	.Link
		https://docs.microsoft.com/en-us/windows/threat-protection/windows-defender-antivirus/deployment-vdi-windows-defender-antivirus
		https://docs.microsoft.com/en-us/windows/threat-protection/windows-defender-antivirus/command-line-arguments-windows-defender-antivirus
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	$Product = "Windows Defender"
	$ProductPath = "${env:ProgramFiles}\$Product"
	$ServiceName = 'WinDefend'
}

Process {
		function MSCrun
		{        
			Write-BISFLog -Msg "Check Silentswitch..."
			$varCLI = $LIC_BISF_CLI_AV
		
			If (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
				Write-BISFLog -Msg "Silentswitch will be set to $varCLI"
			} Else {
           		Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
				$MPFullScan = Show-BISFMessageBox -Msg "Would you like to to run a Full Scan ?" -Title "$Product" -YesNo -Question
        		Write-BISFLog -Msg "$MPFullScan will be choosen [YES = Running Full Scan] [NO = No scan will be performed]"
			}
        
			If (($MPFullScan -eq "YES" ) -or ($varCLI -eq "YES")) {
				Write-BISFLog -Msg "Updating virus signatures... please wait"
				Start-Process -FilePath "$ProductPath\MpCMDrun.exe" -ArgumentList "-SignatureUpdate" -WindowStyle Hidden
				Show-BISFProgressBar -CheckProcess "MpCMDrun" -ActivityText "$Product is updating the virus signatures...please wait"

				Write-BISFLog -Msg "Running Full Scan...please wait"
				Start-Process -FilePath "$ProductPath\MpCMDrun.exe" -ArgumentList "-scan -scantype 2" -WindowStyle Hidden
				Show-BISFProgressBar -CheckProcess "MpCMDrun" -ActivityText "$Product is scanning the system...please wait"		
			} Else {
				Write-BISFLog -Msg "No Full Scan will be performed"
			}
		}


	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
	If (Test-BISFService -ServiceName $ServiceName)
	{
		If ((Get-Service -Name $ServiceName).Status -eq 'Running')
		{
			Write-BISFLog -Msg "$Product is installed and activated" -ShowConsole -Color Cyan
			MSCrun
		} Else {
			Write-BISFLog -Msg "$Product is installed, but not activated" 
		}
	} Else {
		Write-BISFLog -Msg "$Product is not installed" 
	}

}

End {
	Add-BISFFinishLine
}


