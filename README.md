# New Relic Veeam on host integration

## Installation

Install the New Relic Infrastructure agent for Microsoft Windows: https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/windows-installation/install-infrastructure-agent-windows-server-using-msi-installer

Copy directory `integrations.d` and `newrelic-integrations` to `C:\Program Files\New Relic\newrelic-infra\`.

The directory structure should look like this:
```
newrelic-infra\
    integrations.d\
        veeam-monitoring.yaml
    newrelic-integrations\
        veeam-stats.bat
        veeam-stats.ps1
```

Change configuration of `integrations.d\veeam-monitoring.yaml` with your preferred values.

Restart the agent: https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/manage-your-agent/start-stop-restart-infrastructure-agent

# Thank you to

- @jorgedlcruz - Jorge de la Cruz
- @r4yfx - Raymond Setchfield
- @jeffcasavant Jeff Casavant

For creating and maintaining the Grafana exporter: https://github.com/jorgedlcruz/veeam_grafana

- Markus Kraus

For creating the original PRTG script: https://github.com/mycloudrevolution/Advanced-PRTG-Sensors/blob/master/Veeam/PRTG-VeeamBRStats.ps1

- Shawn

For creating an awesome reporting script: http://blog.smasterson.com/2016/02/16/veeam-v9-my-veeam-report-v9-0-1/
