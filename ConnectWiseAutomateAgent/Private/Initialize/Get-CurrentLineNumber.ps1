function Get-CurrentLineNumber {
    [Alias('LINENUM')]
    param()
    $MyInvocation.ScriptLineNumber
}