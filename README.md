# wg-secure

This is a set of scripts to set up a wireguard server at home, to allow connections to your self hosted services. The reason to write a new tool (apart from the challenge of it) was to set up firewall rules dynamically according to the clients' access levels. The tool allows the user to set up clients with various levels of access, and generates the postup script to update the firewall rules accordingly. This allows for fine control over what each client is allowed to access.

The tool is written entirely as bash scripts, not because it is the best way to do this, but because I was curious about it. Maybe someday I will rewrite the whole thing in Python.

## Prerequisites

You must have `wireguard-tools` installed on your system and in your PATH. If you wish to generate QR codes for the client configs, please also install `qrencode`.

On Fedora:
```bash
dnf install wireguard-tools qrencode
```

On Debian:
```bash
apt install wireguard-tools qrencode
```

## Initializing

Clone the git repo and step into the repo folder.
```bash
git clone ...
cd wg-secure
```

__NOTE__: Currently, you must first create and edit the `.env` file before the first run. I will try to add an interactive setup for this later.

First you must copy the `sample.env` file to `.env` file, and edit the values of the variables there. Please check the comments to understand what the variable should contain.
```bash
cp sample.env .env
```

After you have created the `.env` file and edited the necessary variables, you can run the command to initialize the wireguard interface. It will create a new interface for you and will prepare the firewall rules.

This command as all other commands here will need to be performed as root.
```bash
sudo ./wireguard-secure init
```

In case something goes wrong here, you can clear all existing configs and try again after fixing the issue.
```bash
sudo ./wg-secure clear-all
```

You now have a wireguard interface and it should be up. But there are still no clients yet.

## Adding a client

You can add a client like this:
```bash
sudo ./wg-secure add -a FULL -d 0 client-name
```
Here, the `-a` flag refers to access. Access can be `FULL`, where the client is allowed to access everything on the internet and the intranet; `INTERNET`, where the client gets access to everything except the local subnet; `INTRANET`, where the client gets access to only the local subnet, or you define custom access levels in the `.env` file and use those. They will take the form of `CUSTOM_0` for the 1st custom rule, `CUSTOM_1` for the 2nd and so forth.

The `-d` flag refers to the DNS, which specifies if the DNS resolver should be pushed to the client. `0` for false and `1` for true.

You can omit both the flags, if you want to use the default values from the `.env` file.

On adding each new client, a new client config is generated and saved, which you can access and push to your client when desired. The firewall rules are also automatically adjusted according to the existing clients.

## Removing a client

You can remove a client like this:
```bash
sudo ./wg-secure remove client-name
```

On removing a client, the client's access is immediately removed and the client will not be able to connect anymore to the wireguard server.The firewall rules are also adjusted.

## List clients

List all existing clients like this:
```bash
sudo ./wg-secure list
```

## Show a client config

To see a client config:
```bash
sudo ./wg-secure show client-name
```

Or you can add a `-q` flag to see it as a QR code
```bash
sudo ./wg-secure show -q client-name
```

## Clear everything (remove the interface and all clients)

To clear the interface and clients:
```bash
sudo ./wg-secure clear-all
```
You will be asked to confirm this command as it will irrevocably delete all your configs.
