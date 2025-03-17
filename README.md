# TFTPD Docker Container

Source: <https://github.com/LearningToPi/tftpd_docker>

Docker Hub: <https://hub.docker.com/r/learningtopi/tftpd>

## Overview

This container image creates a tftpd-hpa TFTP server running in a container.  The container allows for running both IPv4 and IPv6 listeners.  Container environment variables can be used to control the service.

## Container Environment Variables

| Variable | Options | Default | Description |
| :------- | :------ | :------ | :---------- |
| WRITE_ENABLED | Yes\|No | Yes | Enables write access to the TFTP file share |
| IPV4_ONLY | Yes\|No | Yes | Enables IPv4 ONLY (disables IPv6) |
| IPV6_ONLY | Yes\|No | Yes | Enables IPv6 ONLY (disables IPv4) |
| WORLD_READABLE | Yes\|No | No | If Yes, set the umask to 0111, otherwise sets to 0117 |
| DEBUG | Yes\|No | No | Enables verbose logging for the tftpd-hpa service |
| BLOCKSIZE | (int) | 1400 | Sets the max permitted block size |
| DATA_PATH | (path in container) | /tftp | Path for reading / writing in the container |

## IPv6 Notes

tftp-hpa will listen on either IPv4 or IPv6.  By default we will enable listening on both.  IPv6 can be disabled by adding `-e IPV6=No` to your docker run.

>NOTE: Be sure to forward IPv6 ports to the container!  The same ports numbers will be used for the IPv4 and IPv6:

    -p [::]:69:69/udp

## Using the docker Volume or binding

The tftp container will read/write to the `/tftp` folder by default.  This will be automatically created as a docker volume for persisitance, however to ensure that data is persistent, we recommend either creating a named volume before starting the container, or using a bind mountpoint.

1. Create a docker volume first, then start the container with the volume mounted:

        docker volume create tftp
        docker run ... -v tftp:/tftp ... learningtopi/tftpd:latest

2. Mount the folder to a path outside the container:

> NOTE: If using a user namespace, make sure you apply appropriate ownership and permissions!  See User Namespaces section for more details.

    mkdir /data/tftp
    chown : /data/[username]
    docker run ... -v /data/[username]:/ftp/[username]:Z ... learningtopi/vsftpd:latest

> NOTE: If using a system with SELinux enabled, be sure to add the `:Z` at the end.  This will force a remap of the labels, otherwise access issues may occur.

## Running the container

The following examples can be used to start the container:

    docker run --name tftpd -d -v /data/tftp:/tftp:Z -e WORLD_READABLE=Yes -p 0.0.0.0:69:69/udp -p [::]:69:69/udp --network netv6 learningtopi/tftpd:latest

The preceding is an example that mounts external folders for for the tftp data.  IPv4 and IPv6 ports are both forwarded to the container, and the container is placed on the `netv6` network (which would need both ipv4 and ipv6 enabled).

## User Namespaces

If running docker or podman with user namespaces, the uid/gid of the users in the container will map to different uid/gid numbers in the base system.  If you are using docker volumes, this can be safely ignored, however if you are binding to a path outside of the container, care must be taken to apply proper folder ownership / permissions.

Depending on your containerization platform, the namespace use will be different.  Docker and podman are outlined below.

### Docker User Namespaces

> For more information on docker container isolation with a user namespace, please review dockers documentation: <https://docs.docker.com/engine/security/userns-remap/>.  The info here is not intended to be a holistic review of namespaces.

if user namespaces are enabled for docker (generally done by adding `"userns-remap": "default"` to the `/etc/docker/daemon.json` config file), then all container will run under the default `dockremap` account.  The user accounts in the container will be dynamically generated based on the information in the `/etc/subuid` and `/etc/subbgid` files.  The files have the following format:

    [username]:[starting-id]:[number-of-ids]

Both the `/etc/subuid` and `/etc/subgid` files will require an entry for the `dockremap` account (generally they should have the same values).  The starting ID + the number of ID's should not overlap with any other uid / gid range (other entries in `subuid` or `subgid`, or uid ranges for LDAP / Active Directory etc.)  The following example will be used (for both `/etc/subuid` and `/etc/subgid`):

    dockremap:90000:65536

This will start dynamic container ID's at 90000 and allows for up to 65536 (or a max id of 155536).  For each container that is run with userns enabed, the `root` uid in the container will map to uid 90000 in the host operating system.  The uid (or gid) for any user in a container will be the uid in the container added to 90000.

The default tftpd user account uses a uid of 100 and a gid of 101.  In this case the host uid would be 90100 and gid would be 90101.

Example:

    # Create the tftp directory locally
    mkdir /data/tftp

    # set the ownership
    chown 90100:90101 /data/tftp

    # start the container with the mapping
    docker run ... -v /data/tftp:/tftp ... learningtopi/tftpd:latest

If you want to add permissions for non container accounts to read the FTP data, you can add these using POSIX ACL's:

    # grant [username] read/write/execute access to the tftp folder
    setfacl -m u:[username]:rwx /data/tftp
    # grant [username] read/write/execute access to all files that are CREATED in the tftp folder
    setfacl -d -m u:[username]:rwx /data/tftp

The second command will set the default ACL that will apply to all new files created in the directory (if this path is mounted on an NFS share, then you will likely need to use NFS ACL's instead).

> WARNING!  Docker uses the same remapping for all containers.  This means if you have a uid of 1001 in the vsftpd container, and a uid of 1001 in another container, on the base system these will both map to 91001!  This may be a security concern.  If this is an issue and you cannot use different uid values inside the containers, then you may want to consider podman instead.

### Podman Namespaces

Podman namespaces work similar to docker with one major exception.  Rather than using the `dockremap` user for all remapping, the remapping is based on the user that started the container.  In this case, the `/etc/subuid` and `/etc/subgid` files will need to container an entry for each user that needs to start containers:

    [user1]:100000:65536
    [user2]:165537:65536

User remapping is done different based on the user namespace mode selected (see here for details: <https://www.redhat.com/en/blog/rootless-podman-user-namespace-modes>).

In the default mode (`--userns=""`), the root user in the container will be mapped to the uid of the user that started the container.  

## Troubleshooting

1. If you are testing tftp using the `tftp` or `curl` cli utilities on a linux machine and you receive a timeout on the client, or the server reports `No route to host` or `Connection refused`, this is likely a firewall issue on your client (not the server!)  The TFTP process is as follows:

    1. Client opens a connection on udp/69 to the server (source port is a high random port number)
    2. Server replies to the client sourcing from a high port number to the client source port from #1 (this is an option acknowledgement)
    3. Client sends an acknowledgement and requests the first data block, source from the client source port in #1, destination to the server high port number from #2
    4. Server send data using the high port number from #2 as source and destination port as client high port number

    Since the traffic flow occurs over dynamic high port numbers, if the firewall does not inspect and mark the packet as related to the initial flow, it will be dropped.  If running firewalld, disable with `sudo systemctl stop firewalld` and re-test.

    Most likely you are using the tftp server for data transfers to "dumb" devices that are not likely to have this type of firewall, so this is most likely only relevant to testing.  Remember to re-enable your firewall with `sudo systemctl start firewalld` after you finish testing!

2. If you have IPv6 enabled, but it constantly falls back to IPv4:

        :~$ sudo ftp [hostname]
        Trying [fc00:xxxx::xxxx:xxxx:xxxx:xxxx]:21 ...
        ftp: Can't connect to `fc00:xxxx::xxxx:xxxx:xxxx:xxxx:21': Permission denied
        Trying 192.168.xxx.xxx:21 ...
        Connected to [hostname].
        220 (vsFTPd 3.0.5)
        Name ([hostname]): 
        EOF received; login aborted.
        ftp> ^D
        221 Goodbye.

    1. Check that you have the appropriate IPv6 ports forwarded.  At a minimum you need "-p [::]:21:21/tcp", but should also have "-p [::]:10090-10100:10090-10100/tcp" as well for passive FTP.
    2. Verify that you have IPv6 configured for your docker network.  The default docker bridge "bridge" does NOT have IPv6 enabled!

            $ docker network inspect bridge
            [
                {
                    "Name": "bridge",
                    "Id": "...",
                    "Created": "2025-02-28T09:57:29.588405254-07:00",
                    "Scope": "local",
                    "Driver": "bridge",
                    "EnableIPv4": true,
                    "EnableIPv6": false,
                    "IPAM": {
                        "Driver": "default",
                        "Options": null,
                        "Config": [
                            {
                                "Subnet": "172.17.0.0/16",
                                "Gateway": "172.17.0.1"
                            }
                        ]
                    }
                }
            ]

        Create a new docker network using the following:

            docker network create --driver bridge --ipv6 --ipv4 --subnet 172.18.0.0/24 --subnet fd00::/64 netv6

        Then add "--network netv6" to your docker run command to start the container on the newly created docker network.
