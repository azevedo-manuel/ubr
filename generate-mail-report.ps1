# Create the report
# Mail the report v0.1
# 
# (c) 2016 Manuel Azevedo
#
# From Microsoft's documentation:
# Send-MailMessage [-To] <String[]> [-Subject] <String> [[-Body] <String> ] [[-SmtpServer] <String> ] -From <String> [-Attachments <String[]> ] [-Bcc <String[]> ] [-BodyAsHtml] [-Cc <String[]> ] [-Credential <PSCredential> ] [-DeliveryNotificationOption <DeliveryNotificationOptions> {None | OnSuccess | OnFailure | Delay | Never} ] [-Encoding <Encoding> ] [-Port <Int32> ] [-Priority <MailPriority> {Normal | Low | High} ] [-UseSsl] [ <CommonParameters>]
#
# The default script expects no authentication. If you require, please read PowerShell documentation at https://technet.microsoft.com/en-us/library/hh849925.aspx
#


# Parameters to configure
$EmailFrom    = "VoIPBackup@example.com"
$EmailTo      = "user@example.com"
$EmailCC      = "" # If used, please add  -Cc $EmailCC   to the Send-MailMessage command below
$EmailBCC     = "" # If used, please add  -Bcc $EmailBCC to the Send-MailMessage command below
$Subject      = "VOIP EMEA Backup report"
$SMTPServer   = "smtp.example.com"
$SMTPPort     = "25"
$SMTPPriority = "Normal"
$uBRexe       = ".\ubr.exe"
$debug        = $True

# Make the report. If uBR is not found, report it in the email
if (Test-Path $uBRexe) {
    $body = [string] (& $uBRexe)
} else {
    $Subject = "ERROR: "+$Subject
    $body = "<b>$uBRexe not found</b>"
}

if ($debug){
    write-host "Sending the following info:
    From:     $EmailFrom
    To:       $EmailTo
    CC:       $EmailCC
    BCC:      $EmailBCC
    Subject:  $Subject
    SMTP:     $SMTPServer
    Port:     $SMTPPort
    Priority: $SMTPPriority
    uBRexe:   $uBRexe
    Body:     $body
"
}

# Mail it
Send-MailMessage -From $EmailFrom -To $EmailTo  -Subject $Subject -Body $body -BodyAsHtml -SmtpServer $SMTPServer -Port $SMTPPort -Priority $SMTPPriority  

