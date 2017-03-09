Configuration InstallOctopusTentacle
{
    param ($ListenPort)

    Import-DscResource -Module OctopusDSC

    Node "localhost"
    {
        cTentacleAgent OctopusTentacle
        {
            Ensure = "Present"
            State = "Stopped"
			RegisterWithServer = $False
			
            # Tentacle instance name. Leave it as 'Tentacle' unless you have more
            # than one instance
            Name = "Tentacle"

            # Defaults to <MachineName>_<InstanceName> unless overridden
            DisplayName = "My Tentacle"

            # Registration - all parameters required
			ApiKey = "XX"
            OctopusServerUrl = "http://www.example.com"

            # Optional settings
            ListenPort = 10933
            #DefaultApplicationDirectory = "C:\Applications"
            #TentacleHomeDirectory = "C:\Octopus"
        }
    }
}