[Full README](README.md)

# Logs

`<source>` is `/opt/high-fortress-user/src` after the curl installer, or the clone directory. `YYYYMMDD-HHMMSS` is the stamp `date +%Y%m%d-%H%M%S`.

| Path                                                                           | Who writes                          | When                                                                                                                 |
| ------------------------------------------------------------------------------ | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| <source>/logs/install-YYYYMMDD-HHMMSS-user/install.log                         | scripts/run.sh via init_install_log | During installation.                                                                                                 |
| <source>/logs/install-YYYYMMDD-HHMMSS-user/errors.log                          | error()                             | When a step fails.                                                                                                   |
| <source>/logs/install-YYYYMMDD-HHMMSS-user/meta.txt                            | init_install_log                    | When the log directory is created.                                                                                   |
| <source>/logs/install-YYYYMMDD-HHMMSS-user/steps/INDEX.tsv                     | step_on                             | At each install step.                                                                                                |
| <source>/logs/install-YYYYMMDD-HHMMSS-user/aide-init.log                       | service/aide/init-db.sh             | When the baseline is first built. Fallback path if HF_LOG_DIR is unset: `/var/log/high-fortress-user/aide-init.log`. |
| /opt/high-fortress-user/cron/security_logs/aide-YYYYMMDD-HHMMSS.log            | aide.sh                             | Boot scan, when AIDE runs.                                                                                           |
| /opt/high-fortress-user/cron/security_logs/rkhunter-YYYYMMDD-HHMMSS.log        | rkhunter.sh                         | Boot scan.                                                                                                           |
| /opt/high-fortress-user/cron/security_logs/chkrootkit-YYYYMMDD-HHMMSS.log      | chkrootkit.sh                       | Boot scan.                                                                                                           |
| /opt/high-fortress-user/cron/security_logs/clamav-YYYYMMDD-HHMMSS.log          | clamav.sh                           | Boot scan.                                                                                                           |
| /opt/high-fortress-user/cron/security_logs/clamav-onaccess-YYYYMMDD-HHMMSS.log | clamav-event.sh                     | When on-access finds a real file. A lock name exits before this file is written.                                                |
| /opt/high-fortress-user/cron/security_logs/debsums-YYYYMMDD-HHMMSS.log         | debsums.sh                          | Boot scan.                                                                                                           |
| /opt/high-fortress-user/cron/alerts/<tool>-YYYYMMDD-HHMMSS.txt                 | log_alert                           | Same moment as the security journal, only when an alert is raised.                                                   |
| /var/log/clamav/clamonacc.log                                                  | clamonacc                           | While the on-access service runs.                                                                                    |
| /var/log/lynis.log                                                             | lynis                               | During `hf lynis` or `verify/workstation.sh`. Mode 640.                                                              |
| /var/log/lynis-report.dat                                                      | lynis                               | Same run. Mode 640.                                                                                                  |
| <source>/logs/lynis-<stamp>/                                                   | core/lynis.sh                       | When you run `sudo ./hf lynis`.                                                                                      |
| <source>/logs/verify-report-WORKSTATION-YYYYMMDD-HHMMSS.md                     | verify/workstation.sh               | During workstation verification, under HF_LOG_DIR when that variable is set.                                         |
| systemd journal, unit hfu-boot-scan.service                                    | systemd                             | Each boot scan.                                                                                                      |
