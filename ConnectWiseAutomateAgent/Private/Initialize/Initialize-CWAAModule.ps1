Function Initialize-CWAAModule {
    #Populate $Script:LTServiceKeys Object
    $Script:LTServiceKeys = New-Object -TypeName PSObject
    Add-Member -InputObject $Script:LTServiceKeys -MemberType NoteProperty -Name ServerPasswordString -Value ''
    Add-Member -InputObject $Script:LTServiceKeys -MemberType NoteProperty -Name PasswordString -Value ''

    #Populate $Script:LTProxy Object
    Try{
        $Script:LTProxy = New-Object -TypeName PSObject
        Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name ProxyServerURL -Value ''
        Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name ProxyUsername -Value ''
        Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name ProxyPassword -Value ''
        Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name Enabled -Value ''

        #Populate $Script:LTWebProxy Object
        $Script:LTWebProxy = New-Object System.Net.WebProxy

        #Initialize $Script:LTServiceNetWebClient Object
        $Script:LTServiceNetWebClient = New-Object System.Net.WebClient
        $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
    } Catch {
        Write-Error "ERROR: Line $(LINENUM): Failed Initializing internal Proxy Objects/Variables."
    }

    $Null  = Get-CWAAProxy -ErrorAction Continue
}