<#
    .SYNOPSIS
        Prepare Splunk Universal Fowarder for Image Management
	.Description
      	delete Computer specified entries
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH

		History
      	Last Change: 15.12.2014 JP: Script created
		Last Change: 06.02.2015 MS: review script
		Last Change: 01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		Last Change: 28.05.2018 MS: Bugfix 41: Set SplunkForwarder to StartType Automatic
	.Link
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "Splunk Universal Forwarder"
	$product_path = "${env:ProgramFiles}\SplunkUniversalForwarder\bin"
	$servicename = "SplunkForwarder"
}

Process {
	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true)
	{
		Invoke-BISFService -ServiceName "$servicename" -Action Stop -StartType Automatic
		Write-BISFLog -Msg "Clear $Product config"
        & Start-Process -FilePath "$product_path\splunk.exe" -ArgumentList "clone-prep-clear-config" -Wait -WindowStyle Hidden
	}
}

End {
	Add-BISFFinishLine
}