# PowerDNS with PowerDNS-Admin and PostgreSQL backend

This is KOTS app delivered as a Helm chart for the [PowerDNS](https://www.powerdns.com/) DNS authoritative DNS server, the PowerDNS recursor, and the Postgres backend for persistence, with the [PowerDNS-Admin]() web interface for management.

It is designed to be deployed as part of the Replicated Embedded Cluster and to act as the authoritative DNS server for the local network.

The recursor will be configured to accept queries from clients on the local network at UDP and TCP port 53 and will redirect queries for the local domain to the authoritative server; the authoritative server will be configured to answer queries only from the recursor.

Ingress is configured to expose the PowerDNS-Admin web interface. The first time a user logs in will create the initial admin user. Do not expose the application to the internet until the initial admin user is created and proper security measures are in place.

Storage is configured to use a PersistentVolumeClaim for the Postgres database.
