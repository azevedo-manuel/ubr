# ubr
UCOS backup reporter - ubr

Ever wondered if your UCOS (CUCM, CUCX, PLM, UCCX, etc...) backups are OK?
Ever wondered how many do you have and what space each one uses?

ubr is a tool to create a report based on your backup folder hierarchy.
It will:
* Crawl all folders from a base directory, searching for files with "*drfComponent.xml". These are UCOS backups
* For each XML file, it will check features and components and recreate the name of the component TAR file
* Checks if CUCM considered the backup a sucess (based on the info in the XML file)
* Check if the TAR component file is there
* Sum all the TAR component file sizes and generate a total per backup
* Recursively do this for all files
* Generate an HTML report.

You can either show this report as a CGI page or you can email it. Better, you can put it in a cron job and send it regularly.

Note: UCOS XML files do not contain a readable checksum, so it's impossible to validate if the component TAR file is OK. 
ubr simply checks if the file exists and adds it's size to the backup size.

