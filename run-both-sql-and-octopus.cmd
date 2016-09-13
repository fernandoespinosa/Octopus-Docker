@echo off

echo Setting up data folder structure
if not exist c:\temp\octopus-mapped-volumes\logs mkdir c:\temp\octopus-mapped-volumes\logs
if not exist c:\temp\octopus-mapped-volumes\artifacts mkdir c:\temp\octopus-mapped-volumes\artifacts
if not exist c:\temp\octopus-mapped-volumes\packagecache mkdir c:\temp\octopus-mapped-volumes\packagecache
if not exist c:\temp\octopus-mapped-volumes\packages mkdir c:\temp\octopus-mapped-volumes\packages
if not exist c:\temp\octopus-mapped-volumes\tasklogs mkdir c:\temp\octopus-mapped-volumes\tasklogs

rem hacky way of getting round docker bug https://github.com/docker/docker/issues/26178
powershell -command $env:masterKey -replace '=', '##equals##' ^| Set-Content -path '.run.tmp'
set /p masterKey=<.run.tmp

echo Starting SQL Server

rem rem Using custom image, while waiting for https://github.com/Microsoft/sql-server-samples/pull/106
rem rem Once the official image - microsoft/mssql-server-2014-express-windows - supports health checks, we should use that
rem docker run --interactive ^
rem            --tty ^
rem            --detach ^
rem            --publish 1433:1433 ^
rem            --name=OctopusDeploySqlServer ^
rem            --env sa_password=Password1! ^
rem            octopusdeploy/mssql-server-2014-express-windows
rem 
rem rem ########## start: wait until sql server is ready ##########
rem set CheckCount=0
rem :checkhealth
rem set /a CheckCount=%CheckCount%+1
rem if %checkcount% gtr 30 (
rem   echo Waited 5 minutes for SQL Server to come alive, but it didn't. Aborting.
rem   exit 1
rem )
rem 
rem powershell -command ($(docker inspect OctopusDeploySqlServer) ^| ConvertFrom-Json).State.Health.Status ^| Set-Content -path '.run.tmp'
rem set /p OctopusDeploySqlServerContainerHealth=<.run.tmp
rem del .run.tmp
rem 
rem if "%OctopusDeploySqlServerContainerHealth%" equ "" (
rem   echo SQL Server container does not exist. Aborting.
rem   exit 2
rem )
rem 
rem echo [Attempt %CheckCount%/12] OctopusDeploySqlServer container health state is '%OctopusDeploySqlServerContainerHealth%'
rem if "%OctopusDeploySqlServerContainerHealth%" equ "starting" (
rem     echo Sleeping for 10 seconds
rem     powershell -command sleep 10
rem     goto checkhealth:
rem )
rem if "%OctopusDeploySqlServerContainerHealth%" neq "healthy" (
rem     docker inspect OctopusDeploySqlServer
rem     exit 3
rem )
rem rem ########## end: wait until sql server is ready ##########

docker run --interactive ^
           --tty ^
           --publish 1433:1433 ^
           --name=OctopusDeploySqlServer ^
           --env sa_password=Password1! ^
           microsoft/mssql-server-2014-express-windows

echo "Sleeping for 2 minutes until SQL Server is up and running (hacky)"
powershell -command "sleep 120"

rem hacky way of getting the container's ip address, as --link doesn't work on windows
powershell -command ($(docker inspect OctopusDeploySqlServer) ^| ConvertFrom-Json).NetworkSettings.Networks.nat.IpAddress ^| Set-Content -path '.run.tmp'
set /p sqlServerContainerIpAddress=<.run.tmp

set sqlDbConnectionString=Server=tcp:%sqlServerContainerIpAddress%,1433;Initial Catalog=Octopus;Persist Security Info=False;User ID=sa;Password=Password1!;MultipleActiveResultSets=False;Connection Timeout=30;
rem hacky way of getting round docker bug https://github.com/docker/docker/issues/26178
powershell -command $env:sqlDbConnectionString -replace '=', '##equals##' ^| Set-Content -path '.run.tmp'
set /p sqlDbConnectionString=<.run.tmp

del .run.tmp

echo Starting OctopusDeploy
docker run --interactive ^
           --tty ^
           --name=OctopusDeploy ^
           --publish 81:81 ^
           --env sqlDbConnectionString="%sqlDbConnectionString%" ^
           --env masterKey=%masterkey% ^
           --volume c:/temp/octopus-mapped-volumes/logs:c:/Octopus/Logs ^
           --volume c:/temp/octopus-mapped-volumes/artifacts:c:/Octopus/Artifacts ^
           --volume c:/temp/octopus-mapped-volumes/packagecache:c:/Octopus/OctopusServer/PackageCache ^
           --volume c:/temp/octopus-mapped-volumes/packages:c:/Octopus/Packages ^
           --volume c:/temp/octopus-mapped-volumes/tasklogs:c:/Octopus/TaskLogs ^
           octopusdeploy/octopusdeploy:3.4.2

rem ########## start: wait until octopus is ready ##########
set OctopusDeployCheckCount=0
:octopusdeploycheckhealth
set /a OctopusDeployCheckCount=%OctopusDeployCheckCount%+1
if %OctopusDeployCheckCount% gtr 30 (
  echo Waited 5 minutes for Octopus Deploy to come alive, but it didn't. Aborting.
  exit 4
)

powershell -command ($(docker inspect OctopusDeploy) ^| ConvertFrom-Json).State.Health.Status ^| Set-Content -path '.run.tmp'
set /p OctopusDeployContainerHealth=<.run.tmp
del .run.tmp

if "%OctopusDeployContainerHealth%" equ "" (
  echo OctopusDeploy container does not exist. Aborting.
  exit 5
)

echo [Attempt %OctopusDeployCheckCount%/12] OctopusDeploy container health state is '%OctopusDeployContainerHealth%'
if "%OctopusDeployContainerHealth%" equ "starting" (
    echo Sleeping for 10 seconds
    powershell -command sleep 10
    goto octopusdeploycheckhealth:
)
if "%OctopusDeployContainerHealth%" neq "healthy" (
    docker inspect OctopusDeploy
    exit 6
)

rem ########## end: wait until octopus is ready ##########

echo Done. Octopus is available on port 81.
